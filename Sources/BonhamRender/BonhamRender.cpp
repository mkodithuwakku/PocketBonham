#include "BonhamRender.h"
#include <atomic>
#include <array>
#include <vector>
#include <cmath>
#include <algorithm>
#include <cstring>

namespace {
static_assert(std::atomic<double>::is_always_lock_free && std::atomic<uint64_t>::is_always_lock_free && std::atomic<float>::is_always_lock_free, "Render atomics must be lock-free.");
constexpr int Samples=256, Voices=64, PlanSlots=8, Queue=512;
struct Step { int enabled=0, level=100, retriggers=1; float pitch=0, decay=1; int64_t eligible=0; };
struct Track { int sample=-1, hat=0; float level=.8f, pitch=0, decay=1; Step steps[16]; };
struct Entry { int bpm=120, repeats=1; double swing=.5; float room=0; Track tracks[16]; };
struct Sample { std::vector<float> pcm; int frames=0; };
struct Voice { bool active=false; int sample=0,hat=0; double pos=0,rate=1; float gain=0; int64_t age=0,startedFrame=-1; int remaining=0,release=0,releaseTotal=0; };
struct Live { int sample,hat; float gain,pitch,decay; int kind=0; uint64_t serial=0; };
struct Scheduled { int64_t frame; int sample,hat; float gain,pitch,decay; int step; };
inline int64_t rounded(double d) { return (int64_t)std::llround(d); }
inline double onset(int step, double quarter, double swing) { return (step/2 + (step%2 ? swing : 0)) * quarter/2; }
struct Room {
    float buffer[2][4][2400]{}; int cursor[2][4]{}; float damp[2][4]{};
    void clear() { std::memset(buffer,0,sizeof(buffer)); std::memset(cursor,0,sizeof(cursor)); std::memset(damp,0,sizeof(damp)); }
    void tick(float l,float r,float &ol,float &orr,double rate) {
        const int lengths[2][4]={{1423,1559,1747,1999},{1481,1613,1801,2081}}; float out[2]{};
        for(int c=0;c<2;c++) for(int j=0;j<4;j++) {
            int n=std::min(2399,std::max(1,(int)(lengths[c][j]*rate/48000.)));
            int &p=cursor[c][j]; if(p>=n)p=0;
            float v=buffer[c][j][p]; damp[c][j]=.55f*damp[c][j]+.45f*v;
            buffer[c][j][p]=(c==0?l:r)*.22f + damp[c][j]*.63f;
            out[c]+=v*.5f; p=(p+1)%n;
        } ol=out[0]; orr=out[1];
    }
};
}
struct PBPlan { int count=1,chain=0; Entry entries[64]; };
struct Slot { std::atomic<int> state{0}; PBPlan plan; bool start=false; uint64_t generation=0; };
struct PBEngine {
    double rate; int loadedSamples=0; Sample samples[Samples]; Voice voices[Voices], retiring[Voices];
    Slot slots[PlanSlots]; std::atomic<int> published{-1}; int current=-1;
    std::atomic<uint64_t> generation{0}; uint64_t seenGeneration=0;
    std::atomic<float> master{.7f},click{.35f}; std::atomic<int> metronome{0};
    std::atomic<int> audible[Samples]; float gains[Samples], targets[Samples]{};
    Live live[Queue]; std::atomic<unsigned> write{0},read{0};
    int motionSample=-1,motionParameter=0;float motionValue=0;
    std::atomic<uint64_t> motionSubmitted{0},motionAck{0};
    PBMotionEvent motionEvents[1024];std::atomic<unsigned> motionWrite{0},motionRead{0};
    int state=0,count=0,entry=0,repeat=0,step=0,nextStep=0,activeBPM=120;
    double activeSwing=.5,barStart=0,nextStepFrame=0,quarter=24000;
    int64_t frame=0,bar=0,age=0; Scheduled events[256]; int eventCount=0,eventIndex=0;
    double clickPhase=0; int clickRemaining=0; float clickAccent=1;
    Room room; float roomMix=0,masterSmooth=.7f; float sincTable[65][256][32]; int stopFade=0; uint64_t stolen=0,dropped=0;
    std::atomic<int> sState{0},sCount{0},sStep{0},sEntry{0},sRepeat{0},sBPM{120},sPending{0},sVoices{0};
    std::atomic<int64_t> sFrame{0},sBar{0}; std::atomic<double> sStart{0},sSwing{.5},sHost{0};
    std::atomic<uint64_t> sStolen{0},sDropped{0};
    bool trace=false; PBEvent traceEvents[65536]; int traceCount=0;
    explicit PBEngine(double r):rate(r) {
        for(int i=0;i<Samples;i++){audible[i]=1;gains[i]=1;}
        for(int c=0;c<=64;c++)for(int phase=0;phase<256;phase++){
            double cutoff=.5+c/128.,weight=0;
            for(int j=0;j<32;j++){double x=phase/256.-(j-15),z=x*cutoff;double w=std::abs(x)>=16?0:(std::abs(z)<1e-9?1:std::sin(M_PI*z)/(M_PI*z))*(.5+.5*std::cos(M_PI*x/16))*cutoff;sincTable[c][phase][j]=(float)w;weight+=w;}
            for(int j=0;j<32;j++)sincTable[c][phase][j]/=(float)weight;
        }
    }
    Entry &e(){return slots[current].plan.entries[entry];}
    void log(int sample,int st,int clickEvent=0){if(trace&&traceCount<65536)traceEvents[traceCount++]={frame,sample,entry,st,clickEvent};}
    void reset(){motionParameter=0;motionAck=motionSubmitted.load();stopFade=0;state=0;eventCount=eventIndex=0;clickRemaining=0;room.clear();roomMix=0; for(auto &v:voices)v.active=false;for(auto &v:retiring)v.active=false;read.store(write.load(std::memory_order_acquire),std::memory_order_release); if(current>=0){slots[current].state.store(0,std::memory_order_release);current=-1;} }
    void release(Voice &v){if(v.active){int n=std::max(1,(int)(rate*.003));v.release=v.releaseTotal=n;}}
    void trigger(int sample,int hat,float gain,float pitch,float decay,int st){
        if(sample<0||sample>=Samples||samples[sample].frames==0||!audible[sample].load(std::memory_order_relaxed))return;
        // Same-frame hats form a chord. Only earlier hat voices are choked.
        if(hat)for(auto &v:voices)if(v.active&&v.hat&&v.startedFrame<frame)release(v);
        int chosen=-1;float quiet=1e20f;
        for(int i=0;i<Voices;i++){if(!voices[i].active){chosen=i;break;} float q=std::abs(voices[i].gain)*std::min(1.f,voices[i].remaining/(float)(rate*.02)); if(q<quiet||(q==quiet&&voices[i].age<voices[chosen].age)){quiet=q;chosen=i;}}
        if(voices[chosen].active){retiring[chosen]=voices[chosen];release(retiring[chosen]);stolen++;}
        auto &v=voices[chosen]; v=Voice();v.active=true;v.sample=sample;v.hat=hat;v.rate=std::pow(2.,pitch/12.);v.gain=gain;v.age=age++;v.startedFrame=frame;v.remaining=std::max(1,(int)(samples[sample].frames/v.rate*decay));
        log(sample,st);
    }
    void tickClick(bool accent){clickRemaining=(int)(rate*.022);clickPhase=0;clickAccent=accent?1.f:.7f;log(-1,-1,1);}
    void makeEvents(){
        eventCount=eventIndex=0; Entry &en=e();
        double start=barStart+onset(step,quarter,activeSwing),end=barStart+(step==15?quarter*4:onset(step+1,quarter,activeSwing));
        for(auto &t:en.tracks){auto &s=t.steps[step];if(t.sample<0||!s.enabled||s.eligible>bar)continue;
            float pitch=s.pitch,decay=s.decay;
            if(t.sample==motionSample&&motionParameter){
                if(motionParameter==1)pitch=motionValue;else decay=motionValue;
                unsigned w=motionWrite.load(std::memory_order_relaxed),r=motionRead.load(std::memory_order_acquire);
                if(w-r<1024){motionEvents[w%1024]={t.sample,step,motionParameter,motionValue,bar};motionWrite.store(w+1,std::memory_order_release);}else dropped++;
            }
            for(int r=0;r<s.retriggers;r++){Scheduled ev{rounded(start+(end-start)*r/s.retriggers),t.sample,t.hat,t.level*s.level/127.f,pitch,decay,step};
                int k=eventCount++;while(k>0&&events[k-1].frame>ev.frame){events[k]=events[k-1];k--;}events[k]=ev;
            }
        }
    }
    void beginBar(){activeBPM=e().bpm;activeSwing=e().swing;quarter=rate*60/activeBPM;nextStep=0;nextStepFrame=barStart;}
    float sampleAt(const Sample &s,double pos,int channel,double ratio){
        int p=(int)pos;
        if(std::abs(ratio-1.)<1e-9)return p<s.frames?s.pcm[p*2+channel]:0;
        // Precomputed 32-tap, 256-phase windowed-sinc. No transcendental work per output sample.
        int cutoff=std::clamp((int)std::floor((std::min(1.,1./ratio)-.5)*128),0,64);
        int phase=std::clamp((int)((pos-p)*256),0,255);const float *weights=sincTable[cutoff][phase];
        float sum=0;for(int j=0;j<32;j++){int index=p+j-15;if(index>=0&&index<s.frames)sum+=s.pcm[index*2+channel]*weights[j];}return sum;
    }
    void voiceTick(Voice &v,float &l,float &r){
        if(!v.active)return;auto &s=samples[v.sample];
        if(v.remaining<=0||v.pos>=s.frames){v.active=false;return;}
        float envelope=std::min(1.f,v.remaining/(float)std::max(1,(int)(rate*.003)));
        if(v.releaseTotal){envelope*=v.release/(float)v.releaseTotal;if(--v.release<=0){v.active=false;return;}}
        float gain=v.gain*envelope*gains[v.sample];
        l+=sampleAt(s,v.pos,0,v.rate)*gain;r+=sampleAt(s,v.pos,1,v.rate)*gain;v.pos+=v.rate;--v.remaining;
    }
};
extern "C" {
PBEngine *pb_create(double r){return new PBEngine(r);}
void pb_destroy(PBEngine *e){delete e;}
void pb_clear_samples(PBEngine *e){e->reset();for(auto &s:e->samples){s.pcm.clear();s.pcm.shrink_to_fit();s.frames=0;}}
int pb_set_sample(PBEngine *e,int slot,const float *pcm,int frames){if(slot<0||slot>=Samples||frames<=0)return 0;e->samples[slot].pcm.assign(pcm,pcm+frames*2);e->samples[slot].frames=frames;e->loadedSamples=std::max(e->loadedSamples,slot+1);return 1;}
PBPlan *pb_plan_create(int count,int chain){if(count<1||count>64)return nullptr;auto p=new PBPlan();p->count=count;p->chain=chain;return p;}
void pb_plan_destroy(PBPlan *p){delete p;}
void pb_plan_entry(PBPlan*p,int en,int bpm,double swing,int repeats,float room){if(en<0||en>=p->count)return;auto &e=p->entries[en];e.bpm=std::clamp(bpm,40,240);e.swing=std::clamp(swing,.5,.75);e.repeats=std::clamp(repeats,1,16);e.room=std::clamp(room,0.f,.3f);}
void pb_plan_track(PBPlan*p,int en,int tr,int sample,int hat,float level,float pitch,float decay){if(en<0||en>=p->count||tr<0||tr>=16)return;auto&t=p->entries[en].tracks[tr];t.sample=sample;t.hat=hat;t.level=level;t.pitch=pitch;t.decay=decay;}
void pb_plan_step(PBPlan*p,int en,int tr,int st,int enabled,int level,int retriggers,float pitch,float decay,int64_t eligible){if(en<0||en>=p->count||tr<0||tr>=16||st<0||st>=16)return;p->entries[en].tracks[tr].steps[st]={enabled,std::clamp(level,1,127),retriggers==2||retriggers==4||retriggers==8||retriggers==16?retriggers:1,std::clamp(pitch,-12.f,12.f),std::clamp(decay,.05f,1.f),eligible};}
int pb_publish(PBEngine *e,const PBPlan *p,int start){for(int i=0;i<PlanSlots;i++){int expected=0;if(e->slots[i].state.compare_exchange_strong(expected,1,std::memory_order_acquire)){e->slots[i].plan=*p;e->slots[i].start=start;e->slots[i].generation=e->generation.load(std::memory_order_acquire);int old=e->published.exchange(i,std::memory_order_acq_rel);if(old>=0)e->slots[old].state.store(0,std::memory_order_release);return 1;}}return 0;}
void pb_stop(PBEngine *e){e->generation.fetch_add(1,std::memory_order_release);}
void pb_preferences(PBEngine *e,float master,float click,int metro){e->master=std::clamp(master,0.f,1.f);e->click=std::clamp(click,.01f,1.f);e->metronome=metro;}
void pb_audible(PBEngine *e,int sample,int audible){if(sample>=0&&sample<Samples)e->audible[sample]=audible;}
int pb_live(PBEngine *e,int sample,int hat,float gain,float pitch,float decay){auto w=e->write.load(std::memory_order_relaxed),r=e->read.load(std::memory_order_acquire);if(w-r>=Queue)return 0;e->live[w%Queue]={sample,hat,gain,pitch,decay};e->write.store(w+1,std::memory_order_release);return 1;}
uint64_t pb_motion(PBEngine *e,int sample,int parameter,float value){
    auto w=e->write.load(std::memory_order_relaxed),r=e->read.load(std::memory_order_acquire);if(w-r>=Queue)return 0;
    uint64_t serial=e->motionSubmitted.load(std::memory_order_relaxed)+1;
    e->live[w%Queue]={sample,parameter,value,0,0,1,serial};e->motionSubmitted.store(serial,std::memory_order_release);e->write.store(w+1,std::memory_order_release);return serial;
}
uint64_t pb_motion_ack(PBEngine *e){return e->motionAck.load(std::memory_order_acquire);}
int pb_motion_read(PBEngine *e,PBMotionEvent *out,int capacity){auto r=e->motionRead.load(std::memory_order_relaxed),w=e->motionWrite.load(std::memory_order_acquire);int n=std::min((int)(w-r),capacity);for(int i=0;i<n;i++)out[i]=e->motionEvents[(r+i)%1024];e->motionRead.store(r+n,std::memory_order_release);return n;}
void pb_render(PBEngine *e,float *left,float *right,uint32_t n,double host){
    auto gen=e->generation.load(std::memory_order_acquire);if(gen!=e->seenGeneration){
        e->motionParameter=0;e->motionAck=e->motionSubmitted.load();e->state=0;e->eventCount=e->eventIndex=0;e->stopFade=std::max(1,(int)(e->rate*.003));
        for(auto &v:e->voices)e->release(v);for(auto &v:e->retiring)e->release(v);
        e->read.store(e->write.load(std::memory_order_acquire),std::memory_order_release);
        if(e->current>=0){e->slots[e->current].state.store(0,std::memory_order_release);e->current=-1;}
        e->seenGeneration=gen;
    }
    int fresh=e->published.exchange(-1,std::memory_order_acq_rel);
    if(fresh>=0){auto &s=e->slots[fresh];if(s.generation!=gen)s.state.store(0,std::memory_order_release);else{
        bool start=s.start;if(start)e->reset();else if(e->current>=0)e->slots[e->current].state.store(0,std::memory_order_release);e->current=fresh;
        if(start){e->state=1;e->count=0;e->entry=e->repeat=e->step=0;e->frame=e->bar=0;e->barStart=0;e->quarter=e->rate*60/e->e().bpm;e->activeBPM=e->e().bpm;e->activeSwing=e->e().swing;}
    }}
    auto r=e->read.load(std::memory_order_relaxed),w=e->write.load(std::memory_order_acquire);
    for(;r<w;r++){auto &l=e->live[r%Queue];if(l.kind==1){e->motionSample=l.sample;e->motionParameter=l.hat;e->motionValue=l.gain;e->motionAck.store(l.serial,std::memory_order_release);continue;}e->trigger(l.sample,l.hat,l.gain,l.pitch,l.decay,-1);}e->read.store(r,std::memory_order_release);
    for(int s=0;s<e->loadedSamples;s++)e->targets[s]=e->audible[s].load(std::memory_order_relaxed);
    for(auto &v:e->voices)if(v.active&&!e->targets[v.sample]&&!v.releaseTotal)e->release(v);
    for(auto &v:e->retiring)if(v.active&&!e->targets[v.sample]&&!v.releaseTotal)e->release(v);
    for(uint32_t i=0;i<n;i++,e->frame++){
        if(e->state==1){if(e->count<4&&e->frame>=rounded(e->count*e->quarter)){e->tickClick(e->count==0);e->count++;}if(e->frame>=rounded(e->quarter*4)){e->state=2;e->barStart=e->quarter*4;e->beginBar();}}
        if(e->state==2){
            if(e->frame>=rounded(e->barStart+4*e->quarter)){
                e->barStart+=4*e->quarter;e->bar++;
                if(e->slots[e->current].plan.chain){if(++e->repeat>=e->e().repeats){e->repeat=0;e->entry=(e->entry+1)%e->slots[e->current].plan.count;}}
                e->beginBar();
            }
            if(e->nextStep<16&&e->frame>=rounded(e->nextStepFrame)){
                e->step=e->nextStep;e->makeEvents();if(e->metronome.load(std::memory_order_relaxed)&&e->step%4==0)e->tickClick(e->step==0);
                e->nextStep++;e->nextStepFrame=e->barStart+onset(e->nextStep,e->quarter,e->activeSwing);
            }
            while(e->eventIndex<e->eventCount&&e->events[e->eventIndex].frame<=e->frame){auto &ev=e->events[e->eventIndex++];
                e->trigger(ev.sample,ev.hat,ev.gain,ev.pitch,ev.decay,ev.step);}
        }
        for(int s=0;s<e->loadedSamples;s++)e->gains[s]+=(e->targets[s]-e->gains[s])*.015f;
        float l=0,rout=0;for(auto &v:e->voices)e->voiceTick(v,l,rout);for(auto &v:e->retiring)e->voiceTick(v,l,rout);
        float wet=e->state&&e->current>=0?e->e().room:0;e->roomMix+=(wet-e->roomMix)*.002f;
        if(e->roomMix>.00001f){float wl,wr;e->room.tick(l,rout,wl,wr,e->rate);l=l*(1-e->roomMix)+wl*e->roomMix;rout=rout*(1-e->roomMix)+wr*e->roomMix;}else if(e->roomMix>0){e->room.clear();e->roomMix=0;}
        if(e->clickRemaining>0){double frequency=e->clickAccent==1?1600:1100;float v=std::sin(e->clickPhase)*e->clickRemaining/(e->rate*.022)*e->click.load(std::memory_order_relaxed)*e->clickAccent;e->clickPhase+=2*M_PI*frequency/e->rate;e->clickRemaining--;l+=v;rout+=v;}
        e->masterSmooth+=(e->master.load(std::memory_order_relaxed)-e->masterSmooth)*.002f;
        l*=e->masterSmooth;rout*=e->masterSmooth;
        if(e->stopFade>0){float fade=e->stopFade/(float)std::max(1,(int)(e->rate*.003));l*=fade;rout*=fade;if(--e->stopFade==0){e->clickRemaining=0;e->room.clear();e->roomMix=0;}}
        // Unity below the ceiling; linked instantaneous peak guard adds zero latency.
        float peak=std::max(std::abs(l),std::abs(rout));float protect=peak>.98f?.98f/peak:1;
        left[i]=std::isfinite(l)?l*protect:0;right[i]=std::isfinite(rout)?rout*protect:0;
    }
    e->sState=e->state;e->sCount=e->state?e->count:0;e->sStep=e->state?e->step:0;e->sEntry=e->entry;e->sRepeat=e->repeat;e->sFrame=e->frame;e->sBar=e->bar;e->sStart=e->barStart;e->sBPM=e->activeBPM;e->sSwing=e->activeSwing;e->sHost=host+n/e->rate;
    e->sPending=e->state==2&&e->current>=0&&(e->activeBPM!=e->e().bpm||e->activeSwing!=e->e().swing);int voices=0;for(auto&v:e->voices)voices+=v.active;e->sVoices=voices;e->sStolen=e->stolen;e->sDropped=e->dropped;
}
PBStatus pb_status(PBEngine *e){return {e->sState.load(),e->sCount.load(),e->sStep.load(),e->sEntry.load(),e->sRepeat.load(),e->sBPM.load(),e->sPending.load(),e->sVoices.load(),e->sFrame.load(),e->sBar.load(),e->sStart.load(),e->sSwing.load(),e->sHost.load(),e->rate,e->sStolen.load(),e->sDropped.load()};}
void pb_trace_enable(PBEngine*e,int enabled){e->trace=enabled;e->traceCount=0;}
int pb_trace_read(PBEngine*e,PBEvent*events,int capacity){int n=std::min(e->traceCount,capacity);std::copy(e->traceEvents,e->traceEvents+n,events);e->traceCount=0;return n;}
}

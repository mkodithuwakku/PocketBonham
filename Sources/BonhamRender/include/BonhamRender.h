#ifndef BONHAM_RENDER_H
#define BONHAM_RENDER_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct PBEngine PBEngine;
typedef struct PBPlan PBPlan;
typedef struct {
    int state; /* 0 stopped, 1 count-in, 2 playing */
    int count, step, entry, repeat, bpm, pending, voices;
    int64_t frame, bar;
    double barStartFrame, swing, hostSeconds, sampleRate;
    uint64_t stolenVoices, droppedCommands;
} PBStatus;
PBEngine *pb_create(double sampleRate);
void pb_destroy(PBEngine *engine);
/* Set/clear samples only with AVAudioEngine stopped. Kernel owns copies. */
void pb_clear_samples(PBEngine *engine);
int pb_set_sample(PBEngine *engine, int slot, const float *stereo, int frames);
PBPlan *pb_plan_create(int entries, int chain);
void pb_plan_destroy(PBPlan *plan);
void pb_plan_entry(PBPlan *, int entry, int bpm, double swing, int repeats, float room);
void pb_plan_track(PBPlan *, int entry, int track, int sample, int hat, float level, float pitch, float decay);
void pb_plan_step(PBPlan *, int entry, int track, int step, int enabled, int level, int retriggers, float pitch, float decay, int64_t eligibleBar);
/* Copies to bounded handoff storage; returns false if full. Producer is serial. */
int pb_publish(PBEngine *, const PBPlan *, int start);
void pb_stop(PBEngine *);
void pb_preferences(PBEngine *, float master, float click, int metronome);
void pb_audible(PBEngine *, int sample, int audible);
int pb_live(PBEngine *, int sample, int hat, float gain, float pitch, float decay);
typedef struct { int sample, step, parameter; float value; int64_t bar; } PBMotionEvent;
uint64_t pb_motion(PBEngine *, int sample, int parameter, float value);
uint64_t pb_motion_ack(PBEngine *);
int pb_motion_read(PBEngine *, PBMotionEvent *, int capacity);
void pb_render(PBEngine *, float *left, float *right, uint32_t frames, double hostSeconds);
PBStatus pb_status(PBEngine *);
/* Render-thread trace for offline verification; disabled by default. */
void pb_trace_enable(PBEngine *, int enabled);
typedef struct { int64_t frame; int sample, entry, step, click; } PBEvent;
int pb_trace_read(PBEngine *, PBEvent *events, int capacity);
#ifdef __cplusplus
}
#endif
#endif

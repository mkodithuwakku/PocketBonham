#!/usr/bin/env python3
"""Deterministic development-only sounds. Never substitutes for owner kits."""
import math, random, struct, wave, json, hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'PocketBonham/Resources/Kits/Development'
root.mkdir(parents=True,exist_ok=True)
rng=random.Random(1234); rate=48000
roles=[('kick','Kick',.5),('snare','Snare',.35),('closedHat','Closed Hat',.13),('openHat','Open Hat',.8),('tomLow','Low Tom',.6),('tomHigh','High Tom',.45),('crash','Crash',1.5),('ride','Ride',1.0)]
items=[]
for idx,(role,name,duration) in enumerate(roles):
    pcm=[]; phase=0
    for n in range(int(rate*duration)):
        t=n/rate; noise=rng.uniform(-1,1)
        if role=='kick':
            phase+=2*math.pi*(48+95*math.exp(-t*35))/rate; value=math.sin(phase)*math.exp(-t*12)*.85
        elif role=='snare': value=(noise*.7+math.sin(2*math.pi*185*t)*.3)*math.exp(-t*19)*.65
        elif role.startswith('tom'): value=math.sin(2*math.pi*(100 if role=='tomLow' else 165)*t)*math.exp(-t*10)*.65
        else: value=(noise*.55+math.sin(2*math.pi*5311*t)*.15+math.sin(2*math.pi*7919*t)*.15)*math.exp(-t*(40 if role=='closedHat' else 5))*.4
        value*=min(1,n/16)*min(1,(int(rate*duration)-n)/144)
        pcm.append(struct.pack('<h',int(max(-1,min(1,value))*32767)))
    file=root/(role+'.wav')
    with wave.open(str(file),'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(pcm))
    item=dict(id=role,name=name,file=file.name,order=idx,sha256=hashlib.sha256(file.read_bytes()).hexdigest())
    if 'Hat' in role: item['chokeGroup']='hats'
    items.append(item)
(root/'manifest.json').write_text(json.dumps(dict(schemaVersion=1,id='development-fixtures',name='Development Sounds',assetVersion=1,developmentFixture=True,instruments=items),indent=2)+'\n')

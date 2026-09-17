#!/usr/bin/env python3
"""Test-only codec fixtures. MP3 regeneration requires lameenc==1.8.1 (not an app dependency)."""
import sys, math, struct, wave
from pathlib import Path
sys.path.insert(0,'/tmp/pb-fixture-tools')
import lameenc
root=Path(__file__).resolve().parents[1]/'Tests/BonhamCoreTests/Fixtures';root.mkdir(parents=True,exist_ok=True)
for rate in [44100,48000]:
 for channels in [1,2]:
  values=[(.4*math.sin(2*math.pi*440*n/rate) if ch==0 else .2*math.sin(2*math.pi*880*n/rate)) for n in range(rate//10) for ch in range(channels)]
  pcm16=b''.join(struct.pack('<h',int(v*32767)) for v in values)
  for width in [2,3,4]:
   if width<4:
    pcm=pcm16 if width==2 else b''.join(int(v*8388607).to_bytes(3,'little',signed=True) for v in values)
    with wave.open(str(root/f'pcm{width*8}-{rate}-{channels}.wav'),'wb') as w:w.setnchannels(channels);w.setsampwidth(width);w.setframerate(rate);w.writeframes(pcm)
   else:
    pcm=b''.join(struct.pack('<f',v) for v in values);fmt=struct.pack('<HHIIHH',3,channels,rate,rate*channels*4,channels*4,32)
    (root/f'float32-{rate}-{channels}.wav').write_bytes(b'RIFF'+struct.pack('<I',36+len(pcm))+b'WAVEfmt '+struct.pack('<I',16)+fmt+b'data'+struct.pack('<I',len(pcm))+pcm)
  enc=lameenc.Encoder();enc.set_bit_rate(128);enc.set_in_sample_rate(rate);enc.set_channels(channels);enc.set_quality(2)
  (root/f'mp3-{rate}-{channels}.mp3').write_bytes(bytes(enc.encode(pcm16)+enc.flush()))

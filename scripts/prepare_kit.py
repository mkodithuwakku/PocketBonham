#!/usr/bin/env python3
"""Offline developer asset integration. Unknown/ambiguous roles require an explicit mapping."""
import argparse, hashlib, json, re, shutil, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ALIASES={'kick':['kick','bassdrum','bd'],'snare':['snare','snaredrum','sd'],'closedHat':['highhat','hihat','closedhat','closedhihat','chh'],'openHat':['openhat','openhihat','ohh'],'tomLow':['lowtom','tomlow','floortom'],'tomMid':['midtom','tommid'],'tomHigh':['hightom','tomhigh'],'crash':['crash','crashcymbal'],'ride':['ride','ridecymbal']}
LABELS={'kick':'Kick','snare':'Snare','closedHat':'Closed Hat','openHat':'Open Hat','tomLow':'Low Tom','tomMid':'Mid Tom','tomHigh':'High Tom','crash':'Crash','ride':'Ride'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('folder',type=Path);p.add_argument('--id',required=True);p.add_argument('--name',required=True);p.add_argument('--version',type=int,default=1);p.add_argument('--mapping',type=Path,help='JSON mapping from exact filename to {id,name,order[,startFrame,endFrame,chokeGroup,hatType]}');p.add_argument('--install',action='store_true',help='Validate and copy the kit into bundled resources. Default only proposes a mapping.');a=p.parse_args()
 if not re.fullmatch(r'[a-z0-9][a-z0-9-]*',a.id):p.error('Use a stable lowercase alphanumeric kit ID with hyphens.')
 overrides=json.loads(a.mapping.read_text()) if a.mapping else {}
 files=sorted(f for f in a.folder.iterdir() if f.suffix.lower() in ['.wav','.mp3'] and f.is_file())
 if not 1<=len(files)<=16:p.error(f'Expected 1–16 one-shot audio files; found {len(files)}.')
 instruments=[];problems=[]
 for f in files:
  normalized=re.sub(r'[\s_-]','',f.stem).lower()
  role=next((role for role,aliases in ALIASES.items() if normalized in aliases),None)
  mapping=overrides.get(f.name)
  if mapping: item=dict(mapping)
  elif role:item={'id':role,'name':LABELS[role],'order':list(ALIASES).index(role)}
  else:problems.append(f'{f.name}: ambiguous instrument; provide explicit id/name/order (numbered tom pitch is never guessed).');continue
  item.update(file=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest())
  if item['id'] in ['closedHat','openHat']:item['chokeGroup']='hats'
  instruments.append(item)
 ids=[i['id'] for i in instruments];orders=[i['order'] for i in instruments]
 if len(set(ids))!=len(ids):problems.append('Two samples map to one role. Resolve the duplicate explicitly.')
 if len(set(orders))!=len(orders):problems.append('Duplicate instrument display order. Set explicit order values.')
 manifest=dict(schemaVersion=1,id=a.id,name=a.name,assetVersion=a.version,instruments=sorted(instruments,key=lambda i:i['order']))
 print(json.dumps(manifest,indent=2))
 if problems:p.error('\n'.join(problems))
 if not a.install:return
 target=ROOT/'PocketBonham/Resources/Kits'/a.id
 if target.exists():p.error('This stable kit ID already exists. Review replacement/version changes explicitly before integrating.')
 with tempfile.TemporaryDirectory(prefix='pocketbonham-kit-') as tmp:
  stage=Path(tmp)/a.id;stage.mkdir()
  for f in files:shutil.copy2(f,stage/f.name)
  (stage/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
  subprocess.run(['swift','run','-c','release','bonham-validate-kit',str(stage)],cwd=ROOT,check=True)
  shutil.copytree(stage,target)
 print(f'Installed bundled kit: {target}')
if __name__=='__main__':main()

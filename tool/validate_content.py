#!/usr/bin/env python3
"""Validate authored data/assets offline. Does not execute Dart or Flutter."""
from pathlib import Path
import copy, json, math, wave
ROOT=Path(__file__).resolve().parents[1]
def validate():
 data=json.loads((ROOT/'assets/rooms/apartment.json').read_text())
 rooms={r['id']:r for r in data['rooms']}; levels=data['levels']
 assert [l['levelId'] for l in levels]==list(range(1,21))
 assert len(data['chapters'])==5
 types={'OBJECT_REMOVED','OBJECT_ADDED','OBJECT_MOVED','OBJECT_ROTATED','OBJECT_RESIZED','COLOR_CHANGED','IMAGE_CHANGED','TEXT_CHANGED','STATE_CHANGED'}
 art={'window','painting','clock','mirror','shelf','light','shadow','sofa','lamp','plant','chair','cushion','table','book','vase','cup','note','key'}
 for r in rooms.values():
  assert len({o['id'] for o in r['objects']})==len(r['objects'])
  assert [o['z'] for o in r['objects']]==sorted(o['z'] for o in r['objects'])
  for o in r['objects']:
   assert o['art'] in art
   assert 0<=o['x']<=1 and 0<=o['y']<=1 and o['width']>0 and o['height']>0
 for l in levels:
  assert len(l['hints'])==3 and all(l['hints'])
  assert 0<l['observationDuration']<30 and 0<l['answerDuration']<30 and l['attempts']>0
  before={o['id']:o for o in rooms[l['roomId']]['objects']}; after=copy.deepcopy(before)
  for change in l['changes']:
   assert change['type'] in types and change['objectId'] in before
   o=after[change['objectId']]
   if change['type']=='OBJECT_REMOVED': o['visible']=False
   elif change['type']=='OBJECT_ADDED': o.update(change['values']); o['visible']=True
   else: o.update(change['values'])
   assert o!=before[o['id']],f"No-op in level {l['levelId']}"
   assert 0<o['x']<1 and 0<o['y']<1
  # A swap is one relational puzzle and both changed objects are valid answers.
  assert len(l['changes'])==1 or l['levelId']==9
  assert before!=after
 assert {l['changes'][0]['type'] for l in levels}==types
 assert {l['levelId'] for l in levels if l.get('storyText')}=={5,10,15,20}
 assert len({l['collectibleId'] for l in levels if l.get('collectibleId')})==4
 for name in ['menu','countdown','flicker','correct','wrong','streak','complete','mystery','ambient']:
  with wave.open(str(ROOT/f'assets/audio/{name}.wav')) as f:
   assert f.getnchannels()==1 and f.getsampwidth()==2 and f.getnframes()>100
 # Model of widened target padding: adjacent vase centers must stay distinct
 # at a 230 logical pixel room width (small phone layout).
 r=rooms['apartment_matching']; objects={o['id']:o for o in r['objects']}
 center=objects['vase2']; padding=18/230
 for adjacent in ['vase1','vase3']:
  assert abs(objects[adjacent]['x']-center['x'])>center['width']/2+padding
 return {'levels':len(levels),'rooms':len(rooms),'chapterDefinitions':len(data['chapters']),
   'changeTypes':len(types),'audioAssets':9,'result':'PASS',
   'scope':'Authored JSON, asset integrity and content constraints only; not Flutter execution.'}
if __name__=='__main__':
 result=validate(); print(json.dumps(result,indent=2)); (ROOT/'content-validation.json').write_text(json.dumps(result,indent=2))

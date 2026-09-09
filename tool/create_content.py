"""Reproducible original apartment data. Edit the JSON directly for new content."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def obj(id, art, x,y,w,h,z=0,**kw):
    return dict(id=id, art=art,x=x,y=y,width=w,height=h,z=z,**kw)
objects = [
obj('window','window',.77,.24,.29,.32),
obj('painting','painting',.31,.235,.225,.225),
obj('clock','clock',.55,.11,.12,.11),
obj('mirror','mirror',.095,.23,.12,.24),
obj('shelf','shelf',.41,.435,.61,.035),
obj('light','light',.87,.58,.24,.33),
obj('shadow','shadow',.845,.855,.19,.14),
obj('sofa','sofa',.38,.645,.53,.26,color=0xffb27f59),
obj('lamp','lamp',.85,.57,.17,.34,z=1),
obj('plant','plant',.10,.58,.16,.25,z=1,color=0xffbd805b),
obj('chair','chair',.91,.755,.14,.20,z=1,color=0xff6c8071),
obj('cushion','cushion',.31,.60,.105,.085,z=2,color=0xff516459,rotation=-.13),
obj('table','table',.47,.845,.39,.21,z=2),
obj('book1','book',.17,.386,.044,.064,z=3,color=0xffcd9d66),
obj('book2','book',.23,.386,.044,.064,z=3,color=0xff863f35),
obj('book3','book',.29,.386,.044,.064,z=3,color=0xffb2b596),
obj('vase1','vase',.385,.387,.05,.067,z=3,color=0xffcbbb98),
obj('vase2','vase',.515,.387,.05,.067,z=3,color=0xffcbbb98),
obj('vase3','vase',.645,.387,.05,.067,z=3,color=0xffcbbb98),
obj('cup','cup',.42,.78,.065,.065,z=4,color=0xff738f85),
obj('note','note',.56,.801,.08,.052,z=4,text='21',rotation=-.1),
obj('key','key',.64,.924,.060,.042,z=4),
obj('oldBook','book',.21,.822,.06,.065,z=4,visible=False,color=0xff863f35,rotation=1.57),
]
def change(type,id,**values): return dict(type=type,objectId=id,values=values)
levels = [dict(levelId=1,roomId='apartment',difficulty='easy',observationDuration=7,answerDuration=7,attempts=3,
    changes=[change('OBJECT_REMOVED','lamp')],hints=['Look to the right.','Near the warm light.','The floor lamp is missing.'])]
(ROOT/'assets/rooms/apartment.json').write_text(json.dumps(dict(schemaVersion=1,rooms=[dict(id='apartment',name='The Apartment',objects=objects)],levels=levels),indent=2))
specs = [
('OBJECT_MOVED','chair',dict(x=.75),['Look near the floor.','Check the right-hand seat.','The chair moved.']),
('OBJECT_MOVED','plant',dict(x=.14,y=.69),['Look on the left.','Follow the leaves.','The plant moved closer to you.']),
('IMAGE_CHANGED','painting',dict(variant='moon'),['Look above the sofa.','Look inside the wooden frame.','The sun became a moon.']),
('COLOR_CHANGED','cup',dict(color=0xffb9684f,variant='striped'),['Look near the table.','Check the little drink.','The cup is orange and striped.']),
('STATE_CHANGED','clock',dict(variant='late'),['Look near the ceiling.','Time looks different.','The clock hand moved.']),
('OBJECT_REMOVED','book2',{},['Look along the shelf.','Check the books.','The red book disappeared.']),
('OBJECT_ROTATED','cushion',dict(rotation=.65),['Look at the sofa.','Check the green cushion.','The cushion turned.']),
('OBJECT_MOVED','vase1',dict(x=.645),['Look along the shelf.','Compare the two end vases.','The end vases swapped places.']),
('IMAGE_CHANGED','painting',dict(variant='inverted'),['Look at the wall.','Compare the painted hills.','The hill in the painting changed.']),
('OBJECT_REMOVED','key',{},['Look low in the room.','Look beside the rug.','The brass key disappeared.']),
('STATE_CHANGED','shadow',dict(variant='left'),['Look below the lamp.','Which way does the shadow fall?','The floor shadow points the other way.']),
('OBJECT_RESIZED','vase3',dict(scale=1.35),['Look at the shelf.','Compare the ceramic objects.','The right-hand vase grew.']),
('STATE_CHANGED','mirror',dict(variant='other'),['Look at the left wall.','Look inside the small mirror.','The reflected vase moved.']),
('TEXT_CHANGED','note',dict(text='12'),['Look at the table.','Check the paper.','21 became 12.']),
('STATE_CHANGED','mirror',dict(variant='visitor'),['Look at the left wall.','Look inside the reflection.','A silhouette appeared in the mirror.']),
('OBJECT_ADDED','oldBook',{},['Look beside the table.','Have you seen this red object before?','The red book appeared on the floor.']),
('STATE_CHANGED','light',dict(variant='dim'),['Look around the lamp.','Compare its pool of light.','The warm light on the wall dimmed.']),
('STATE_CHANGED','vase2',dict(variant='marked'),['Look along the shelf.','Check the middle vase.','The middle vase gained a stripe.']),
('STATE_CHANGED','clock',dict(variant='impossible'),['Look near the ceiling.','Count the clock hands.','The clock has an impossible extra hour hand.']),
]
# Distinct ends make the swap a fair, visible change.
next(o for o in objects if o['id']=='vase1')['color']=0xffba836b
next(o for o in objects if o['id']=='vase3')['color']=0xff92a393
# Room 19 uses three matching ceramics. Other rooms retain visible distinctions.
matching=json.loads(json.dumps(objects))
for o in matching:
    if o['id'].startswith('vase'): o['color']=0xffcbbb98
stories={5:"You’ve seen this room before.",10:"But you’ve never been here.",15:"Someone else is changing the rooms.",20:"They know you’re watching."}
collect={5:'brass_key',10:'red_book',15:'note_21',20:'mirror'}
for i,(t,id,v,hints) in enumerate(specs,2):
    changes=[change(t,id,**v)]
    if i==9: changes.append(change('OBJECT_MOVED','vase3',x=.385))
    levels.append(dict(levelId=i,roomId='apartment_matching' if i==19 else 'apartment',
        difficulty='easy' if i<=5 else 'medium' if i<=10 else 'hard' if i<=15 else 'very hard',
        observationDuration=7 if i<=10 else 9,answerDuration=7 if i<=5 else 6 if i<=10 else 8,
        attempts=3 if i<=5 else 2, changes=changes,hints=hints,storyText=stories.get(i,''),collectibleId=collect.get(i)))
rooms=[dict(id='apartment',name='The Apartment',objects=objects),dict(id='apartment_matching',name='The Apartment',objects=matching)]
(ROOT/'assets/rooms/apartment.json').write_text(json.dumps(dict(schemaVersion=1,rooms=rooms,levels=levels),indent=2))

# Future chapters carry metadata only; their content remains intentionally empty.
path=ROOT/'assets/rooms/apartment.json'
data=json.loads(path.read_text())
data['chapters']=[dict(id=i+1,title=t,available=i==0,levelIds=list(range(1,21)) if i==0 else []) for i,t in enumerate(['THE APARTMENT','THE HOTEL','THE LABORATORY','THE TRAIN','THE IMPOSSIBLE ROOM'])]
path.write_text(json.dumps(data,indent=2))

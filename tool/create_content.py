"""Authoritative Chapter 1 catalog. Run this file after editing the definitions.

Each tier is a snapshot of the same apartment: furniture never jumps between
layouts. Hidden objects provide addition targets without engine-specific logic.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def obj(id, art, x, y, w, h, z=0, **values):
    return dict(id=id, art=art, x=x, y=y, width=w, height=h, z=z, **values)


objects = [
    obj('window', 'window', .77, .24, .29, .32),
    obj('painting', 'painting', .31, .235, .225, .225),
    obj('clock', 'clock', .55, .11, .12, .11),
    obj('mirror', 'mirror', .095, .23, .14, .26),
    obj('shelf', 'shelf', .41, .435, .61, .035),
    obj('light', 'light', .87, .58, .24, .33),
    obj('shadow', 'shadow', .81, .965, .20, .06),
    obj('sofa', 'sofa', .38, .645, .53, .26, color=0xffb27f59),
    obj('lamp', 'lamp', .85, .57, .17, .34, z=1),
    obj('plant', 'plant', .10, .58, .16, .25, z=1, color=0xffbd805b),
    obj('chair', 'chair', .91, .755, .14, .20, z=1, color=0xff6c8071),
    obj('cushion', 'cushion', .31, .60, .105, .085, z=2, color=0xff516459, rotation=-.13),
    obj('cushion2', 'cushion', .49, .61, .09, .08, z=2, color=0xffc4ae7c, rotation=.12),
    obj('table', 'table', .47, .845, .39, .21, z=2),
    obj('book1', 'book', .17, .385, .044, .09, z=3, color=0xffcd9d66),
    obj('book2', 'book', .23, .385, .044, .09, z=3, color=0xff863f35),
    obj('book3', 'book', .29, .385, .044, .09, z=3, color=0xffb2b596),
    obj('vase1', 'vase', .385, .385, .06, .09, z=3, color=0xffba836b, variant='marked'),
    obj('vase2', 'vase', .515, .385, .06, .09, z=3, color=0xffcbbb98),
    obj('vase3', 'vase', .645, .385, .06, .09, z=3, color=0xff92a393),
    obj('cup', 'cup', .42, .78, .075, .07, z=4, color=0xff738f85),
    obj('note', 'note', .565, .805, .10, .075, z=4, text='21', rotation=-.1),
    obj('key', 'key', .66, .94, .075, .047, z=4),
    obj('oldBook', 'book', .21, .822, .06, .08, z=4, visible=False, color=0xff863f35, rotation=1.57),
    obj('smallFrame', 'painting', .41, .075, .085, .08, z=1),
    obj('calendar', 'note', .965, .52, .055, .075, z=2, text='21'),
    obj('floorBook', 'book', .10, .90, .055, .08, z=4, color=0xffcd9d66, rotation=1.57),
]
# Details arrive between difficulty bands; the main furniture stays in place.
medium = {'mirror', 'book2', 'vase2'}
hard = {'note', 'key', 'cushion2'}
late = {'smallFrame', 'calendar', 'floorBook'}
rooms = []
for tier, hidden in [('apartment', medium | hard | late),
                     ('apartment_medium', hard | late),
                     ('apartment_hard', late),
                     ('apartment_dense', set())]:
    snapshot = copy.deepcopy(objects)
    for o in snapshot:
        if o['id'] in hidden:
            o['visible'] = False
    rooms.append(dict(id=tier, name='The Apartment', objects=sorted(snapshot, key=lambda o: o['z'])))
matching = copy.deepcopy(rooms[-1])
matching['id'] = 'apartment_matching'
for o in matching['objects']:
    if o['id'].startswith('vase'):
        o.update(color=0xffcbbb98, variant='default')
rooms.append(matching)


def change(kind, target, **values):
    return dict(type=kind, objectId=target, values=values)


# Hint text follows the region → object → explicit explanation progression.
specs = [
    ('OBJECT_REMOVED', 'lamp', {}, ['Look to the right.', 'Near the warm light.', 'The floor lamp is missing.']),
    ('OBJECT_MOVED', 'chair', {'x': .79}, ['Look near the floor.', 'Check the right-hand seat.', 'The chair moved to the left.']),
    ('COLOR_CHANGED', 'cup', {'color': 0xffb9684f, 'variant': 'striped'}, ['Look at the table.', 'Check the drink.', 'The cup became orange and striped.']),
    ('OBJECT_ADDED', 'vase2', {}, ['Look along the shelf.', 'Check its open middle space.', 'A third vase appeared in the middle.']),
    ('IMAGE_CHANGED', 'painting', {'variant': 'moon'}, ['Look above the sofa.', 'Look inside the wooden frame.', 'The painted sun became a moon.']),
    ('OBJECT_REMOVED', 'book2', {}, ['Look along the shelf.', 'Check the three book spines.', 'The red book disappeared.']),
    ('STATE_CHANGED', 'clock', {'variant': 'late'}, ['Look near the ceiling.', 'Check the time.', 'The clock hour hand moved.']),
    ('OBJECT_ROTATED', 'cushion', {'rotation': .65}, ['Look at the sofa.', 'Check the green cushion.', 'The green cushion turned.']),
    ('OBJECT_MOVED', 'vase1', {'x': .645}, ['Look along the shelf.', 'Compare the two end vases.', 'The striped and plain end vases swapped.']),
    ('STATE_CHANGED', 'vase2', {'variant': 'marked'}, ['Look along the shelf.', 'Check the middle ceramic.', 'The middle vase gained a stripe.']),
    ('OBJECT_RESIZED', 'vase3', {'scale': 1.3, 'y': .3715}, ['Look at the shelf.', 'Compare the ceramic silhouettes.', 'The right-hand vase grew.']),
    ('OBJECT_REMOVED', 'key', {}, ['Look low in the room.', 'Check the floor beside the rug.', 'The brass key disappeared.']),
    ('TEXT_CHANGED', 'note', {'text': '12'}, ['Look at the table.', 'Read the paper again.', '21 became 12 on the note.']),
    ('STATE_CHANGED', 'shadow', {'variant': 'left'}, ['Look below the chair.', 'Which way does the shadow fall?', 'The floor shadow points the other way.']),
    ('STATE_CHANGED', 'mirror', {'variant': 'other'}, ['Look at the left wall.', 'Look inside the small mirror.', 'The reflected vase moved to the right.']),
    ('IMAGE_CHANGED', 'mirror', {'variant': 'echo'}, ['Look at the left wall.', 'Study the reflected vase.', 'A stripe appeared only on the reflected vase.']),
    ('OBJECT_ADDED', 'oldBook', {}, ['Look beside the table.', 'Remember the red book on the shelf.', 'Another red book appeared on the floor.']),
    ('OBJECT_ROTATED', 'book3', {'rotation': .22}, ['Look along the shelf.', 'Compare the book spines.', 'The pale book is leaning now.']),
    ('STATE_CHANGED', 'vase2', {'variant': 'marked'}, ['Look along the shelf.', 'Compare the three matching ceramics.', 'Only the middle vase gained a stripe.']),
    ('STATE_CHANGED', 'window', {'variant': 'double_moon'}, ['Look toward the night sky.', 'Compare the two upper window panes.', 'There are two moons outside the window.']),
]
stories = {5: 'You’ve seen this room before.', 10: 'But you’ve never been here.',
           15: 'Someone else is changing the rooms.', 20: 'They know you’re watching.'}
collectibles = {5: 'brass_key', 10: 'red_book', 15: 'note_21', 20: 'mirror'}
levels = []
for i, (kind, target, values, hints) in enumerate(specs, 1):
    band = (i - 1) // 5
    changes = [change(kind, target, **values)]
    if i == 9:
        changes.append(change('OBJECT_MOVED', 'vase3', x=.385))
    levels.append(dict(levelId=i,
                       roomId='apartment_matching' if i == 19 else rooms[band]['id'],
                       difficulty=['easy', 'medium', 'hard', 'very hard'][band],
                       observationDuration=[7, 8, 10, 12][band],
                       answerDuration=[7, 8, 9, 10][band], attempts=3 if band == 0 else 2,
                       changes=changes, hints=hints, storyText=stories.get(i, ''),
                       collectibleId=collectibles.get(i)))
chapters = [dict(id=i+1, title=title, available=i == 0,
                 levelIds=list(range(1, 21)) if i == 0 else [])
            for i, title in enumerate(['THE APARTMENT', 'THE HOTEL', 'THE LABORATORY',
                                      'THE TRAIN', 'THE IMPOSSIBLE ROOM'])]
if __name__ == '__main__':
    (ROOT / 'assets/rooms/apartment.json').write_text(json.dumps(
        dict(schemaVersion=1, rooms=rooms, levels=levels, chapters=chapters), indent=2) + '\n')

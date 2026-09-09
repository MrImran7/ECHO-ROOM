class CollectibleDefinition {
  const CollectibleDefinition(
    this.id,
    this.art,
    this.name,
    this.description,
    this.level,
  );
  final String id, art, name, description;
  final int level;
}

const collectibles = [
  CollectibleDefinition(
    'brass_key',
    'key',
    'A familiar key',
    'It fits a door you cannot remember.',
    5,
  ),
  CollectibleDefinition(
    'red_book',
    'book',
    'The red book',
    'Every page has your handwriting.',
    10,
  ),
  CollectibleDefinition(
    'note_21',
    'note',
    'Room 21',
    'There are only twenty rooms.',
    15,
  ),
  CollectibleDefinition(
    'mirror',
    'mirror',
    'The witness',
    'Your reflection stayed behind.',
    20,
  ),
];

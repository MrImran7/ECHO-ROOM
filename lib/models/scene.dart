import 'dart:math' as math;

typedef Json = Map<String, dynamic>;
double number(Object? value, [double fallback = 0]) => (value as num?)?.toDouble() ?? fallback;

/// Positions and sizes are normalized to a room's artboard, not the device.
class RoomObject {
  const RoomObject({required this.id, required this.art, required this.x,
    required this.y, required this.width, required this.height, this.rotation = 0,
    this.scale = 1, this.visible = true, this.z = 0, this.color = 0xffbd7355,
    this.text = '', this.variant = 'default', this.asset, this.hitPadding = .015});
  final String id, art, text, variant;
  final String? asset;
  final double x, y, width, height, rotation, scale, hitPadding;
  final bool visible;
  final int z, color;
  factory RoomObject.fromJson(Json j) => RoomObject(
    id: j['id'] as String, art: j['art'] as String, x: number(j['x']), y: number(j['y']),
    width: number(j['width']), height: number(j['height']), rotation: number(j['rotation']),
    scale: number(j['scale'], 1), visible: j['visible'] as bool? ?? true,
    z: j['z'] as int? ?? 0, color: j['color'] as int? ?? 0xffbd7355,
    text: j['text'] as String? ?? '', variant: j['variant'] as String? ?? 'default',
    asset: j['asset'] as String?, hitPadding: number(j['hitPadding'], .015));
  Json toJson() => {'id': id, 'art': art, 'x': x, 'y': y, 'width': width,
    'height': height, 'rotation': rotation, 'scale': scale, 'visible': visible,
    'z': z, 'color': color, 'text': text, 'variant': variant, 'asset': asset, 'hitPadding': hitPadding};
  void validate() {
    if (id.isEmpty || art.isEmpty ||
        [x, y, width, height, rotation, scale, hitPadding].any((v) => !v.isFinite) ||
        x < 0 || x > 1 || y < 0 || y > 1 || width <= 0 || height <= 0 ||
        scale <= 0 || hitPadding < 0) {
      throw FormatException('Invalid room object: $id');
    }
  }
  RoomObject patch(Json patch) => RoomObject.fromJson({...toJson(), ...patch, 'id': id});
  bool contains(double px, double py, {double padding = 0}) {
    // Work in the 400x440 artboard so rotations use the same metric as rendering.
    final dx = (px - x) * 400, dy = (py - y) * 440;
    final rx = dx * math.cos(rotation) + dy * math.sin(rotation);
    final ry = -dx * math.sin(rotation) + dy * math.cos(rotation);
    return rx.abs() <= width * scale * 200 + padding * 400 &&
        ry.abs() <= height * scale * 220 + padding * 440;
  }
}

List<RoomObject> _zOrdered(Iterable<RoomObject> objects) {
  final result = objects.toList();
  final order = {for (var i = 0; i < result.length; i++) result[i].id: i};
  result.sort((a, b) {
    final z = a.z.compareTo(b.z);
    return z != 0 ? z : order[a.id]!.compareTo(order[b.id]!);
  });
  return List.unmodifiable(result);
}

class Room {
  Room({required this.id, required this.name, required List<RoomObject> objects})
      : objects = _zOrdered(objects);
  final String id, name;
  final List<RoomObject> objects;
  Json toJson() => {'id': id, 'name': name, 'objects': objects.map((o) => o.toJson()).toList()};
  factory Room.fromJson(Json j) => Room(id: j['id'] as String, name: j['name'] as String,
      objects: (j['objects'] as List<dynamic>).map((e) => RoomObject.fromJson(e as Json)).toList());
}

class RoomState {
  RoomState(Iterable<RoomObject> objects) : objects = _zOrdered(objects);
  final List<RoomObject> objects;
  RoomObject object(String id) => objects.firstWhere((o) => o.id == id);
}

/// String types and a registry allow future changes without changing saved data.
class Change {
  const Change({required this.type, required this.objectId, required this.values});
  final String type, objectId;
  final Json values;
  factory Change.fromJson(Json j) => Change(type: j['type'] as String,
    objectId: j['objectId'] as String, values: j['values'] as Json? ?? {});
  Json toJson() => {'type': type, 'objectId': objectId, 'values': values};
}

typedef ChangeTransform = RoomObject Function(RoomObject object, Json values);
class ChangeRegistry {
  ChangeRegistry() {
    for (final type in ['OBJECT_MOVED', 'OBJECT_ROTATED', 'OBJECT_RESIZED',
      'COLOR_CHANGED', 'IMAGE_CHANGED', 'TEXT_CHANGED', 'STATE_CHANGED']) {
      transforms[type] = (o, v) => o.patch(v);
    }
    transforms['OBJECT_REMOVED'] = (o, v) => o.patch({'visible': false});
    transforms['OBJECT_ADDED'] = (o, v) => o.patch({...v, 'visible': true});
  }
  final Map<String, ChangeTransform> transforms = {};
  RoomState apply(RoomState original, List<Change> changes) {
    final result = original.objects.toList();
    for (final change in changes) {
      final index = result.indexWhere((o) => o.id == change.objectId);
      final transform = transforms[change.type];
      if (index < 0 || transform == null) throw FormatException('Invalid change ${change.toJson()}');
      result[index] = transform(result[index], change.values);
      result[index].validate();
    }
    return RoomState(result);
  }
}

class LevelDefinition {
  const LevelDefinition({required this.levelId, required this.roomId,
    required this.changes, required this.difficulty, required this.hints,
    this.observationDuration = 7, this.answerDuration = 5, this.attempts = 2,
    this.storyText = '', this.collectibleId});
  final int levelId, attempts;
  final String roomId, difficulty, storyText;
  final String? collectibleId;
  final double observationDuration, answerDuration;
  final List<Change> changes;
  final List<String> hints;
  Json toJson() => {'levelId': levelId, 'roomId': roomId, 'changes': changes.map((c) => c.toJson()).toList(),
    'difficulty': difficulty, 'hints': hints, 'observationDuration': observationDuration,
    'answerDuration': answerDuration, 'attempts': attempts, 'storyText': storyText, 'collectibleId': collectibleId};
  Set<String> get targets => changes.map((c) => c.objectId).toSet();
  factory LevelDefinition.fromJson(Json j) => LevelDefinition(levelId: j['levelId'] as int,
    roomId: j['roomId'] as String, difficulty: j['difficulty'] as String,
    changes: (j['changes'] as List<dynamic>).map((e) => Change.fromJson(e as Json)).toList(),
    hints: (j['hints'] as List<dynamic>).cast<String>(),
    observationDuration: number(j['observationDuration'], 7), answerDuration: number(j['answerDuration'], 5),
    attempts: j['attempts'] as int? ?? 2, storyText: j['storyText'] as String? ?? '',
    collectibleId: j['collectibleId'] as String?);
}

import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/scene.dart';
import '../models/chapter.dart';

class GameCatalog {
  GameCatalog({required this.rooms, required this.levels, this.chapters = const []});
  final Map<String, Room> rooms;
  final List<LevelDefinition> levels;
  final List<ChapterDefinition> chapters;
  LevelDefinition level(int id) => levels.firstWhere((l) => l.levelId == id);
  static Future<GameCatalog> load() async {
    final data = jsonDecode(await rootBundle.loadString('assets/rooms/apartment.json')) as Json;
    final rooms = (data['rooms'] as List<dynamic>).map((j) => Room.fromJson(j as Json));
    final catalog = GameCatalog(rooms: {for (final r in rooms) r.id: r},
      chapters: (data['chapters'] as List<dynamic>? ?? []).map((j) => ChapterDefinition.fromJson(j as Json)).toList(),
      levels: (data['levels'] as List<dynamic>).map((j) => LevelDefinition.fromJson(j as Json)).toList());
    catalog.validate(); return catalog;
  }
  void validate() {
    if (levels.isEmpty) throw const FormatException('No levels');
    for (final room in rooms.values) {
      for (final object in room.objects) { object.validate(); }
    }
    for (var i = 0; i < levels.length; i++) {
      final l = levels[i], room = rooms[levels[i].roomId];
      if (l.levelId != i + 1 || room == null || l.changes.isEmpty || l.hints.length != 3 ||
          !l.observationDuration.isFinite || !l.answerDuration.isFinite || l.observationDuration <= 0 || l.answerDuration <= 0 || l.attempts < 1) {
        throw FormatException('Invalid level ${l.levelId}');
      }
      if (room.objects.map((o) => o.id).toSet().length != room.objects.length) throw const FormatException('Duplicate object');
      ChangeRegistry().apply(RoomState(room.objects), l.changes);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:echo_room/game/session.dart';
import 'package:echo_room/levels/catalog.dart';
import 'package:echo_room/models/scene.dart';
import 'package:echo_room/models/progress.dart';
import 'package:echo_room/services/audio_service.dart';

GameCatalog loadCatalog() {
  final j = jsonDecode(
    File('assets/rooms/apartment.json').readAsStringSync(),
  ) as Json;
  final rooms = (j['rooms'] as List<dynamic>).map(
    (r) => Room.fromJson(r as Json),
  );
  return GameCatalog(
    rooms: {for (final r in rooms) r.id: r},
    levels: (j['levels'] as List<dynamic>)
        .map((l) => LevelDefinition.fromJson(l as Json))
        .toList(),
  );
}

GameSession session({int level = 1, String? daily, String runId = 'test'}) {
  final catalog = loadCatalog(), definition = loadCatalog().level(level);
  return GameSession(
    level: definition,
    room: catalog.rooms[definition.roomId]!,
    runId: runId,
    dailyDate: daily,
  )..ready();
}

void reachAnswer(GameSession s) {
  s.ready();
  for (var i = 0; i < 500 && s.phase != GamePhase.answering; i++) {
    s.advance(.05);
  }
}

void win(GameSession s, {double elapsed = .5}) {
  reachAnswer(s);
  s.advance(elapsed);
  var found = false;
  for (var y = 0; y <= 100 && !found; y++) {
    for (var x = 0; x <= 100 && !found; x++) {
      if (s.targets.contains(s.hitTester.resolve(x / 100, y / 100))) {
        s.tap(x / 100, y / 100);
        found = true;
      }
    }
  }
  s.advance(1.01);
}

class SilentAudio implements AudioService {
  @override
  void configure(UserSettings settings) {}
  @override
  void cue(SoundCue cue) {}
  @override
  Future<void> dispose() async {}
  @override
  void resume() {}
  @override
  void suspend() {}
}

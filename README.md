# ECHO ROOM

An offline visual-memory game built with Flutter, Flame and Riverpod. Observe a cozy apartment, survive a brief blackout, then tap the detail that changed. Chapter 1 contains 20 data-driven puzzles using original procedural artwork and audio.

## Run

Install stable Flutter (Dart 3.11 or later), Android SDK/JDK 17, and optionally Xcode on macOS. Native host projects are generated from the installed Flutter templates:

```sh
python3 tool/bootstrap.py
flutter pub get
flutter run
```

## Architecture

- `lib/game/`: deterministic session state machine, hit testing, scoring and Flame rendering.
- `lib/models/`, `lib/levels/`: immutable scene snapshots and catalog validation.
- `lib/app/`: Riverpod dependencies and application theme.
- `lib/screens/`, `lib/widgets/`: navigation, HUD and a viewport owning one Flame clock.
- `lib/services/`, `lib/storage/`: audio, haptics, progression and serialized local persistence.
- `lib/daily/`, `lib/achievements/`, `lib/collection/`: existing supporting systems.
- `assets/rooms/apartment.json`: chapter, room and level definitions.
- `test/`: rules, content, persistence, controller and widget regression tests.
- `tool/`: native-host bootstrap and validation helpers.

The session moves through loading → intro → countdown → observing → flicker → blackout → answering. Correct taps show one second of feedback before completion. Wrong taps briefly lock input while the answer clock continues; timeout reveals the answer before failure. Only answering accepts taps. Pausing retains the prior phase and requires explicit resume. Rendering owns the clock; widgets do not assign phases or run gameplay timers.

Progress checkpoints include timing and feedback state. Completed run IDs make result writes idempotent. A repository abstraction serializes writes; screens never access preferences directly. Daily attempts are reserved before gameplay begins.

## Add rooms and levels

Add a room entry with a unique ID and objects to the JSON catalog. Object centers and dimensions are normalized to a 400×440 artboard, maintained at that aspect ratio. Give objects stable IDs, appropriate z-order and touch padding. Add a renderer in `RoomArt` for a new procedural art kind, or supply a bundled asset path declared in `pubspec.yaml`. Image assets load once before the session starts.

Add a sequential level entry referencing the room, with observation/answer durations, attempts, difficulty, three hint strings and a change list. Optional story and collectible IDs stay in data. No engine edits are needed for existing change kinds.

`ChangeRegistry` copies the original objects into a modified `RoomState`. Supported types are `OBJECT_REMOVED`, `OBJECT_ADDED`, `OBJECT_MOVED`, `OBJECT_ROTATED`, `OBJECT_RESIZED`, `COLOR_CHANGED`, `IMAGE_CHANGED`, `TEXT_CHANGED`, and `STATE_CHANGED`. Added objects begin hidden in the base room. Register a transform for a new type. Removed and moved targets retain historical hit regions; overlapping regions resolve by z-order, geometry and distance. The debug outlines use this same geometry.

## Debug and validation

Debug builds expose level unlocking/selection, skipped countdown/observation, hitboxes, hints and progress/lives resets in Settings/Chapters. Build-time lives options are in `GameConfig`; debug controls are omitted in release builds. Reset progress requires confirmation.

```sh
dart format .
flutter analyze
flutter test
flutter build apk --debug
# macOS with Xcode:
flutter build ios --simulator --debug
```

`python3 tool/validate.py` bootstraps native hosts and runs the Flutter gates. It reports blocked checks explicitly when Flutter is absent. GitHub Actions runs Android and iOS validation. Python content and lexical checks are supplementary and do not establish Flutter compilation or device performance.

A physical-device pass is still needed for audio/haptics, interruption behavior, safe areas and frame pacing before release. The local daily challenge has no online leaderboard; ads are mock interfaces and no account or sensitive permissions are required.

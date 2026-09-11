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

## Chapter 1 — The Apartment

The catalog has four cumulative detail tiers (17, 20, 23 and 26 visible objects),
plus a matching-ceramics variant. Main furniture keeps the same coordinates in
each tier. Later levels gain inspection time instead of relying on shorter timers.

| Levels | Difficulty | Observe / answer | Changes in order |
| --- | --- | --- | --- |
| 1–5 | Easy | 7s / 7s | Lamp removed; chair moved; striped cup recolored; vase added; painting changed |
| 6–10 | Medium | 8s / 8s | Red book removed; clock hand moved; cushion rotated; end vases swapped; vase striped |
| 11–15 | Hard | 10s / 9s | Vase enlarged; key removed; note reversed; floor shadow reversed; reflected vase moved |
| 16–20 | Very hard | 12s / 10s | Reflection-only stripe; earlier red book appears on floor; book leans; matching vase changes; second moon appears |

Only Room 9 changes two objects: one relational swap, with either end accepted.
Room 20 surrounds its impossible sky detail with unchanged repeated numbers,
frames and book motifs. The player still identifies one changed object. Color
puzzles also change patterns, and the swap uses a striped/plain distinction.
Story fragments and collectible milestones remain at rooms 5, 10, 15 and 20.

`tool/create_content.py` is the source for these authored definitions; run it to
regenerate `assets/rooms/apartment.json`. Update both together. Level IDs remain
stable for existing saves and daily history.

`test/chapter_test.dart` checks each room's transitions, target and neighboring
foreground hitboxes at three viewport widths, hints, replay isolation, invalid
data and rendered before/after pixel differences. CI exports the 20 comparison
images as **chapter-1-scene-review**. Images show original on the left and changed
on the right. Existing progression, scoring and real Flame navigation tests also
run. The formatter commit helper supports the named feature branches; no
analysis, test or native build gate is skipped.

## Player progression

Chapter completion counts distinct solved rooms; stars measure mastery separately.
One star requires a solve, two require at most one mistake/hint and a response
within 85% of the room timer, and three require no mistakes/hints within 50%.
Replays keep independent best score, stars and time. Successful solves (including
replays) extend the active streak; failures reset it. Best streak survives restart.
Mastery achievements count distinct rooms, and repeated solves award no hint currency.

New players start with 3 hint units. First clears of rooms 5, 10 and 15 award 2;
room 20 awards 3. Existing hint balances are preserved. Collection holds the four
story milestone objects plus a watch for earning 3 stars in Room 12. Definitions
live in `lib/achievements/` and `lib/collection/`; result processing remains in
`completeSession` in `lib/services/progression_service.dart`, outside the
engine/render loop.

The version-1 save format gains optional cumulative solve, wrong-tap and hint-use
fields. Older saves retain all records/settings; known completed rooms seed the
solve count, and unavailable historical wrong-tap/hint totals start at zero.
These counters track completed Apartment sessions, including failures and replays.
Chapter totals and fastest time are derived from best records, never accumulated.
Reset clears progression while preserving Music, Sound and Haptics preferences.
Achievements and local stats remain viewable in Collection.

### Daily Room

`lib/daily/daily_service.dart` owns the injectable local clock and stable pool-v1
selection. Calendar date fields (YYYY-MM-DD), not elapsed hours or time of day,
select among rooms 6–11 and 13–15. Preserve pool ordering/content within a version;
bump `dailyPoolVersion` for an intentional content change. Existing unfinished
reservations keep their saved level/version.

One official attempt per date; one wrong answer or timeout ends it. Three free
hint strengths use the existing score penalties without spending chapter hints.
Daily play ignores lives and cannot alter chapter records, achievements,
collectibles, stats or gameplay streak. There is no post-result practice mode.

Start and final result are persisted through the existing repository. A killed
app resumes its checkpoint; an unfinished reservation without a checkpoint can
retry. Finishing after midnight still belongs to the start date. Final records
are immutable by date, even with a different run ID. A paused chapter room must
be finished before switching modes because there is one active-session slot.

Consecutive successful calendar dates extend the daily streak; failure or a
skipped day resets it, while best streak remains. Entry/resume/return refresh
local dates, and PLAY rechecks at touch time; there is no midnight polling.
History retains version, puzzle ID, result, score, milliseconds, mistakes and
hints in the existing backward-compatible save envelope. These fields form the
future leaderboard submission payload; no network implementation is included.
Reset Progress clears daily data and keeps sound/music/haptic preferences.
Debug builds show the date, selected puzzle and pool version on Daily Room.

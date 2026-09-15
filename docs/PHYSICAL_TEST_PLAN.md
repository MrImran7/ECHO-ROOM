# Physical test plan

## Purpose and scope

This checklist checks what CI cannot establish: felt vibration, audible timing/quality, touch response, real OS interruption/Back, screen cutouts and perceived frame pacing. Business rules are primarily automated; see [TESTING.md](TESTING.md). Full regression includes user-visible smoke checks of those rules, not manual replacement of unit tests.

All cases are initially **NOT RUN** (all result boxes empty). Select exactly one PASS / FAIL / BLOCKED only after execution. CI must never fill physical results. P0 = must pass before merge/release when applicable; P1 = important regression; P2 = uncommon/polish. Record unexecuted variants explicitly. Keep IDs stable forever; do not renumber cases when inserting new ones.

## Requirements and preparation

- Android phone (generated host minimum is API 24 / Android 7), charged, with an APK/test build for the exact requested commit.
- USB cable and Android platform-tools/ADB, or an APK transfer/install method. No Android Studio is required.
- Sound enabled and media volume audible for audio cases. Android **touch haptics** and the game's Haptics toggle enabled for vibration cases. Notification/keyboard vibration does not establish touch feedback is enabled.
- Record device model, Android version, commit SHA, APK source, date, fresh/upgrade state and tester. Obtain APK from the matching GitHub Actions run → Artifacts → `echo-room-debug-apk`; extract the ZIP. Ask the developer for the APK if artifacts are unavailable.
- Use a disposable test save for destructive cases. Finish the upgrade test before deleting its old data. Reset Progress does not reset onboarding; fresh intro cases require a fresh installation/test profile.

### Install with ADB

Enable USB debugging in the phone's Developer options (usually unlocked by tapping Build number seven times in About phone), connect USB and accept the computer authorization prompt. Menu names vary. Run:

```sh
adb devices
```

The device must show `device`, not `unauthorized`/`offline`. With multiple devices, add `-s <serial>` after `adb` to select the test phone.

Upgrade installation (preserve existing app data):

```sh
adb install -r <apk-path>
```

Replace `<apk-path>` with the actual extracted APK path, for example `build/app/outputs/flutter-apk/app-debug.apk` for a local build. A successful `-r` upgrade preserves data. Package/signing keys must be compatible. CI debug keys can differ between runners: if Android rejects the signature, mark upgrade BLOCKED and ask for compatible signed builds; do not uninstall and report upgrade PASS.

Fresh installation (**deletes old app data**):

```sh
adb uninstall com.imran.games.echo_room
adb install <apk-path>
```

The application ID follows the repository's `tool/bootstrap.py` host generation: `--org com.imran.games --project-name echo_room`, producing `com.imran.games.echo_room`. The displayed name is ECHO ROOM. Fresh install removes old progress; use it only on the designated test save. For manual installation, transfer/open the APK on the phone and allow installation from that file app when Android asks. Choose Update for upgrade; uninstall first only for a deliberate fresh test.

### How to play / test helpers

Home is the main menu. PLAY starts/resumes Chapter play; CHAPTERS selects unlocked rooms. Remember objects while the room is visible, wait through blackout, then tap the changed object. **Room 1 removes the lamp: tap its former position, even though it is empty.** Wrong Chapter answers may permit another attempt; Daily allows one answer attempt.

Pause (top control or Android Back) offers RESUME and SAVE & HOME. Use SAVE & HOME to leave without deliberately failing. Tests involving timing keep debug Skip countdown/observation OFF. If lives run out, debug Settings offers RESET LIVES. Debug +10 HINTS supports chapter hint testing; these helpers affect your test save. Unlock all levels permits selection, not completion; it cannot create a completed Chapter fixture.

Daily entry → OPEN DAILY LAB creates isolated **in-memory** test data. REAL DATE changes its clock only; EXIT LAB restores real player data. Lab cannot test durable process-kill recovery because its data disappears on exit/restart. Use ordinary Daily for persistence cases. No system clock manipulation is needed for routine tests.

## Smoke Test — routine feature build

Run these 15 existing cases (reuse observations from one playthrough). Allow roughly 20–30 minutes plus installation; this is an estimate, not a timed gate. For an established-player-only build, mark fresh/onboarding cases NOT RUN with reason and add the upgrade case. Add affected feature cases from full regression; do not execute every section on every PR.

- ER-INSTALL-001
- ER-ONB-001
- ER-ONB-004
- ER-GAME-001
- ER-GAME-002
- ER-GAME-003
- ER-LIFE-001
- ER-GAME-004
- ER-SET-001
- ER-SET-002
- ER-HINT-001
- ER-DAILY-001
- ER-DAILY-003
- ER-PERSIST-001
- ER-ACCESS-001

## PR #6 / Onboarding Smoke

Execute these IDs against the final PR head. Use separate fresh runs for Continue and Skip; complete the intro for first-star guidance. The upgrade case requires a real old-save fixture. These are the exact pre-merge hardware checks, not CI results:

- ER-INSTALL-001
- ER-INSTALL-002
- ER-ONB-001
- ER-ONB-002
- ER-ONB-003
- ER-ONB-004
- ER-GAME-002
- ER-HINT-001
- ER-DAILY-001
- ER-PERSIST-001
- ER-ACCESS-001
- ER-ACCESS-002
- ER-ACCESS-003
- ER-LIFE-001
- ER-GAME-004

Coverage: fresh/Continue/Skip/restart and upgrade; Level 1 first result; first wrong cue; hint explanation; first Daily intro; How to Play; silent/reduced-motion play; background/Back; larger text and TalkBack. All remain NOT RUN until a tester executes them.

## Full regression cases

Use the affected sections for feature regressions and the complete applicable set for release qualification. Score/streak/migration/isolation assertions are already automated; the physical objective is coherent visible flow and actual OS behavior.

### Installation / upgrade

#### ER-INSTALL-001 — Fresh install and launch

ID: ER-INSTALL-001

Priority: P0

Feature: Fresh install and launch

Preconditions:

- Disposable test save; APK matches the requested commit.

Steps:

1. Follow Fresh install below.
2. Open ECHO ROOM from its icon.
3. Complete the intro using Continue and the final action.
4. Close and reopen the app.

Expected Result:

Intro appears before Home on the fresh installation; no Home flash or crash. Completion lands on Home without starting a room. Reopening goes to Home.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-INSTALL-002 — Upgrade and established-player migration

ID: ER-INSTALL-002

Priority: P0

Feature: Upgrade and established-player migration

Preconditions:

- A prior compatible signed build with solved rooms, changed settings and preferably a paused session; record these values first.

Steps:

1. Install the new APK using the Upgrade instructions without uninstalling.
2. Launch from the icon.
3. Inspect Chapters, Collection, Daily Room and Settings.
4. Resume the paused room if one was saved.

Expected Result:

Saved progress/settings remain. An established legacy user is not forced through the intro. Launch/resume works. An incompatible signing key is BLOCKED, not a reason to delete the upgrade fixture.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Onboarding

#### ER-ONB-001 — Continue, first-session guidance and first result

ID: ER-ONB-001

Priority: P0

Feature: Continue, first-session guidance and first result

Preconditions:

- Fresh test save; complete rather than Skip the intro so optional tips remain eligible.

Steps:

1. Read each intro page and tap Continue; use the final action.
2. On Home tap PLAY.
3. Observe Room 1, then after blackout tap the empty place where the lamp stood.
4. Read the result, scroll if needed, and tap NEXT ROOM.
5. Return Home using Pause then SAVE & HOME.

Expected Result:

Three concise pages lead to Home. Room prompts do not hide objects. First success, stars/unlock and any achievement remain clear; tips do not stack or bury NEXT ROOM. No unsolicited game starts from intro.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-ONB-002 — Skip and rapid actions

ID: ER-ONB-002

Priority: P0

Feature: Skip and rapid actions

Preconditions:

- Separate fresh test save (Reset Progress does not reset intro preferences).

Steps:

1. Tap SKIP rapidly twice.
2. Use Android Back from Home, then reopen the app.
3. Start Room 1 and finish or fail it.

Expected Result:

Skip lands once on Home; intro stays dismissed after restart. No duplicate route/session or forced optional tutorial sequence; essential hint/wrong-tap guidance may still appear.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-ONB-003 — Intro Back and interruption

ID: ER-ONB-003

Priority: P1

Feature: Intro Back and interruption

Preconditions:

- Fresh test save.

Steps:

1. Advance to step 3; press Android Back twice.
2. On each step in a repeat run, press Android Home, wait five seconds, and return.
3. Before finishing the intro, remove the app from Recents and reopen (record whether the OS actually killed it).
4. On step 1 press Android Back.

Expected Result:

Back moves to previous steps, then skips from step 1 without a loop. Background preserves the current step; a genuinely killed unfinished intro restarts at step 1. No completion is saved merely on background.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-ONB-004 — How to Play replay

ID: ER-ONB-004

Priority: P1

Feature: How to Play replay

Preconditions:

- Home available; record current level, stars, lives, hints and Daily status.

Steps:

1. Open Settings → HOW TO PLAY.
2. Read and scroll through the instructions.
3. Press Android Back to Settings, then return Home.
4. Open and close HOW TO PLAY twice quickly.
5. Compare the recorded values.

Expected Result:

Reference is readable and easy to exit. No session starts, resources change, Daily state changes or automatic intro returns. Exact preference invariants are also automated.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Core gameplay

#### ER-GAME-001 — Observe, blackout, touch and correct answer

ID: ER-GAME-001

Priority: P0

Feature: Observe, blackout, touch and correct answer

Preconditions:

- Home; a life available; Settings debug Skip countdown/observation OFF.

Steps:

1. Open CHAPTERS and select Room 1.
2. Remember the lamp position; try a tap during observation.
3. Watch the blackout.
4. When WHAT CHANGED appears, tap the former lamp position once, then rapidly tap again.

Expected Result:

Observation taps have no answer effect. Blackout hides the removal without harsh flashing or visible mutation. Correct feedback feels immediate and highlights the target; extra taps do not create another result.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-GAME-002 — Wrong answer and first cue

ID: ER-GAME-002

Priority: P0

Feature: Wrong answer and first cue

Preconditions:

- Room 1 available; first wrong-tap cue requires a save that has never shown it.

Steps:

1. Start Room 1.
2. After blackout tap a recognizable unchanged object such as the sofa.
3. Read the cue, then tap the missing lamp position while time remains.
4. Replay and make another wrong tap.

Expected Result:

NOT THAT is visible; a short cue on first use does not reveal the answer or cover the room. Correct input returns after brief feedback. No repeated first-use cue or vibration/animation pile-up.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-GAME-003 — Timeout and rapid result navigation

ID: ER-GAME-003

Priority: P1

Feature: Timeout and rapid result navigation

Preconditions:

- Room 1 available.

Steps:

1. Start Room 1 and do not answer.
2. At timeout try tapping the room.
3. On the result rapidly tap REPLAY; then complete the replay and rapidly tap NEXT ROOM.
4. Return Home.

Expected Result:

TIME’S UP stops input, reveals the target and produces one result. Navigation stays responsive with one room/route per action; no stale overlay appears.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-LIFE-001 — Real background, lock and resume

ID: ER-LIFE-001

Priority: P0

Feature: Real background, lock and resume

Preconditions:

- Room 1 available; normal timing enabled.

Steps:

1. During observation press Android Home, wait five seconds and return.
2. Tap RESUME when offered.
3. Repeat on another run during blackout, and another just before answer time expires.
4. Lock the phone for five seconds during play, unlock and resume.

Expected Result:

Game remains paused until resumed; absence does not consume answer time or cause a loss. Correct phase returns without duplicate transitions or stale sound. Record each phase separately.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-GAME-004 — Android Back and saved session

ID: ER-GAME-004

Priority: P0

Feature: Android Back and saved session

Preconditions:

- Active Chapter room.

Steps:

1. Press Android Back during play.
2. Choose SAVE & HOME from the pause options.
3. Tap PLAY to resume.
4. Finish the room and press Android Back from the result.
5. Open Daily entry then press Android Back.

Expected Result:

Back pauses gameplay instead of losing the attempt. SAVE & HOME preserves it. Resuming is coherent; result Back does not recreate gameplay; entry Back returns normally.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Audio / haptics

#### ER-SET-001 — Sound, music and audible feedback

ID: ER-SET-001

Priority: P0

Feature: Sound, music and audible feedback

Preconditions:

- Media volume audible; Sound ON; phone speaker selected.

Steps:

1. Play correct, wrong and timeout outcomes using Room 1 replays.
2. Listen through result transition.
3. In Settings turn Sound OFF and repeat a wrong answer; turn ON and repeat.
4. Toggle Music OFF/ON; background and resume during play.

Expected Result:

Effects are audible, timely and distinct without unpleasant overlap. OFF blocks effects immediately; ON restores future effects. Music follows its toggle when active. No stale sound burst on resume. Record speaker/Bluetooth route; Bluetooth latency is a separate variant.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-SET-002 — Felt haptics and runtime setting

ID: ER-SET-002

Priority: P0

Feature: Felt haptics and runtime setting

Preconditions:

- Android system touch haptics/vibration enabled; ECHO ROOM Haptics ON. Keyboard or notification vibration alone is not sufficient.

Steps:

1. Solve Room 1 and feel the feedback.
2. Replay and tap a wrong object.
3. Turn Haptics OFF in Settings; repeat correct and wrong outcomes.
4. Turn ON and repeat without restarting.
5. Background, return, resume and repeat a correct answer.

Expected Result:

Correct and wrong feedback are perceptible and distinguishable without excessive vibration. OFF produces none; ON and resume restore future feedback. If Android suppresses touch feedback, record BLOCKED and enable its setting before retesting; never bypass OS preferences.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Hints

#### ER-HINT-001 — Chapter hint clarity and sequential strengths

ID: ER-HINT-001

Priority: P0

Feature: Chapter hint clarity and sequential strengths

Preconditions:

- Chapter room; for all strengths use debug Settings +10 HINTS on a disposable save. Costs are 1, 2, then 3 units; initial balance alone is insufficient.

Steps:

1. Start a room and wait for answering.
2. Tap Hint once and read both guidance and first-use consequence text.
3. Use the next two strengths while time remains (repeat on another room if needed).
4. Try rapid taps and inspect the result hints count/score.

Expected Result:

Region, pulse and reveal are understandable and touch-responsive. Guidance is not obscured by the explanation. Used strengths advance once and hints visibly affect the result. Exact cost/score assertions are automated.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Progression

#### ER-PROG-001 — Stars, replay, streak and unlock presentation

ID: ER-PROG-001

Priority: P1

Feature: Stars, replay, streak and unlock presentation

Preconditions:

- Disposable progressed save; record a completed room’s bests and current streak.

Steps:

1. Replay that room with a slower solve or hint, then replay faster without hints.
2. Inspect current result versus saved Chapters rating.
3. Solve consecutive rooms, then fail one.
4. At a new achievement/collectible unlock read the result and open Collection.

Expected Result:

Current run and stored bests are distinguishable; normal progress and streak feedback are readable. New items remain viewable without forced navigation. Best-value, streak and reward-once rules are automated, not a manual arithmetic exercise.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-PROG-002 — Final chapter result and navigation

ID: ER-PROG-002

Priority: P0

Feature: Final chapter result and navigation

Preconditions:

- Test save with Rooms 1–19 completed; obtain from tester’s prior play. Debug Unlock all levels alone does not mark them completed.

Steps:

1. Complete Room 20.
2. Read chapter summary, stars and story; scroll if needed.
3. Use Home/Chapters and replay Room 20.

Expected Result:

Chapter completion and story display correctly; actions stay reachable and no invalid Room 21 starts. If fixture is unavailable mark BLOCKED; automated Level 20 coverage remains independent.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Daily Room

#### ER-DAILY-001 — Daily official flow and first entry

ID: ER-DAILY-001

Priority: P0

Feature: Daily official flow and first entry

Preconditions:

- No active Chapter session; today available, or use isolated Daily Lab for a repeatable smoke variant.

Steps:

1. Open DAILY ROOM from Home and read its date/first-entry explanation.
2. Tap PLAY DAILY ROOM once.
3. Observe then solve (free hint reveal may help).
4. Return Home; reopen Daily Room and inspect history.

Expected Result:

Daily identity/date are clear; result shows time, score and DAILY streak, no Chapter stars. Home shows COMPLETE; entry offers no second official run. History shows the official record. Record whether real or Lab state was tested.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-DAILY-002 — Missed day status and free hint isolation

ID: ER-DAILY-002

Priority: P1

Feature: Missed day status and free hint isolation

Preconditions:

- Use Daily Lab for repeatable dates; record Chapter hints/lives/stars/streak before entering.

Steps:

1. Start a new Lab daily date.
2. Use all three sequential Daily hints; allow timeout or tap a wrong object.
3. Inspect MISSED result/history and attempt to start again.
4. Exit Lab and compare real Chapter/Daily values.

Expected Result:

Hints are labeled free/Daily and their usage is shown; one wrong answer/timeout finalizes failure. No second official run. Real Chapter resources/progression and real Daily records remain unchanged by Lab. Exact isolation is automated.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-DAILY-003 — Real Daily restart/resume

ID: ER-DAILY-003

Priority: P0

Feature: Real Daily restart/resume

Preconditions:

- Ordinary Daily Room (not Lab), today unfinished; no competing Chapter session.

Steps:

1. Start Daily; use a hint during answering.
2. Press Android Back, save and return Home.
3. Close the app from Recents and reopen; if it survives, use Android Settings → Apps → ECHO ROOM → Force stop, then reopen.
4. Choose RESUME DAILY ROOM and finish.
5. Reopen Daily entry again.

Expected Result:

Same reserved puzzle/date resumes from saved state; used hints stay used. One official result persists. No penalty simply for backgrounding. Last checkpoint may precede process death; record phase and any lost recent action.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-DAILY-004 — Daily Lab date and streak scenarios

ID: ER-DAILY-004

Priority: P1

Feature: Daily Lab date and streak scenarios

Preconditions:

- Debug build; record real Home Daily status/history before opening OPEN DAILY LAB from Daily entry.

Steps:

1. Read effective date, real date, pool/puzzle and attempt state.
2. Use OVERRIDE DATE; select a date and CLEAR TODAY if needed.
3. Choose YESTERDAY SOLVED then solve today; inspect streak.
4. Clear unfinished state if necessary; use another date with YESTERDAY FAILED, then MISSED DAY and inspect streak.
5. Use REAL DATE, then EXIT LAB. Restart app.

Expected Result:

Scenario states and labels are clear; consecutive solve extends the simulated streak, failures/gaps reset it. REAL DATE removes only date override within Lab; EXIT LAB restores real data. No Lab state survives exit/restart. Lab buttons may be disabled during an active attempt; use CLEAR INTERRUPTED first.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-DAILY-005 — Real midnight/date refresh

ID: ER-DAILY-005

Priority: P2

Feature: Real midnight/date refresh

Preconditions:

- Real Daily entry near local midnight; optional scheduled release test, not required every PR.

Steps:

1. Before midnight open entry without starting; after midnight return Home and reenter.
2. In a separate run start before midnight and finish after midnight.
3. Background and return to Home.

Expected Result:

Unstarted entry refreshes to the new date. Started attempt/result retains its owning start date. Historical record is unchanged and next-date Home status refreshes. Calendar arithmetic is automated; do not change the phone clock just to run routine smoke.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Persistence

#### ER-PERSIST-001 — Completion/settings survive actual restart

ID: ER-PERSIST-001

Priority: P0

Feature: Completion/settings survive actual restart

Preconditions:

- A solved Chapter room and at least one changed setting.

Steps:

1. Record level, stars, score, hints/lives, Daily status and settings.
2. Force stop via Android Settings → Apps → ECHO ROOM.
3. Reopen from icon and inspect the recorded values.
4. Play another room.

Expected Result:

Saved completion and preferences remain; no repeated intro or broken navigation. Life regeneration may legitimately increase lives with elapsed time. OS persistence is checked here; serialization rules remain automated.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-PERSIST-002 — Reset with confirmation

ID: ER-PERSIST-002

Priority: P1

Feature: Reset with confirmation

Preconditions:

- Disposable save containing progress and Daily data; record sound/music/haptics preferences.

Steps:

1. Open Settings → Reset Progress; cancel first.
2. Check progress still exists.
3. Repeat and confirm reset.
4. Return Home, Chapters and Daily Room; restart the app.

Expected Result:

Cancel preserves everything. Confirm clears game and Daily progress/attempts and restores initial resources. Preferences and seen onboarding stay preserved; How to Play remains available. Today becomes available. Exact reset fields are automated.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-PERSIST-003 — Chapter process death at completion boundary

ID: ER-PERSIST-003

Priority: P1

Feature: Chapter process death at completion boundary

Preconditions:

- Disposable Chapter save; room available.

Steps:

1. Start a room and force stop while observing; reopen and resume.
2. Repeat during answering.
3. On another run solve then close immediately around FOUND IT/result; reopen.
4. Inspect saved result and resume if a checkpoint remains.

Expected Result:

No crash, duplicate reward or permanently stuck session. Recovery reflects the last durable checkpoint; an interrupted completion may need finishing again but must not duplicate its result. Record timing precisely.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Accessibility / UI

#### ER-ACCESS-001 — Large text, narrow viewport and safe areas

ID: ER-ACCESS-001

Priority: P0

Feature: Large text, narrow viewport and safe areas

Preconditions:

- Phone system text settings accessible; record original setting.

Steps:

1. Increase system font size (try approximately 1.3x, 1.5x and largest near 2x if supported).
2. Visit intro on a fresh save, How to Play, Home, Daily entry/history/result and Chapter result.
3. Scroll and operate Skip/Continue/Home and other primary actions.
4. Check around status bar, camera cutout and bottom gesture area; restore text setting.

Expected Result:

Text does not overlap or clip essential actions; scrolling reaches every action without shrinking text excessively. Record actual device/font setting. Automated 320px tests complement this; a wide phone cannot certify narrow hardware.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-ACCESS-002 — Reduced motion and silent play

ID: ER-ACCESS-002

Priority: P1

Feature: Reduced motion and silent play

Preconditions:

- Home; record original system accessibility settings.

Steps:

1. Enable Android Remove animations/reduced motion if available.
2. Turn game Sound and Haptics OFF.
3. Play correct, wrong and timeout outcomes; open Daily entry and How to Play.
4. Restore settings.

Expected Result:

All outcomes and instructions remain clear through visible words/icons. No essential cue depends on animation, sound or vibration; controls stay responsive. If OS option is unavailable mark that variant BLOCKED.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

#### ER-ACCESS-003 — TalkBack and focus order

ID: ER-ACCESS-003

Priority: P1

Feature: TalkBack and focus order

Preconditions:

- Android TalkBack available; know its double-tap-to-activate gesture and how to disable it.

Steps:

1. Enable TalkBack.
2. Read intro/How to Play controls in order.
3. Visit Chapters and a result, then Daily entry.
4. Listen to star ratings and locked level labels; disable TalkBack afterward.

Expected Result:

Headings/descriptions/actions are understandable, decorative icons do not overwhelm speech, and stars are announced as one rating. Report gameplay visual-memory accessibility limitations honestly; this case does not certify a nonvisual puzzle mode.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

### Long-session sanity

#### ER-PERF-001 — Frame pacing and repeated navigation

ID: ER-PERF-001

Priority: P1

Feature: Frame pacing and repeated navigation

Preconditions:

- Charged phone; record model, refresh rate and build; skip timers OFF.

Steps:

1. Play at least ten rooms/replays over ten minutes.
2. Between runs visit Chapters, Collection, Settings and Daily Room.
3. Background/resume twice; watch blackout and touch feedback.
4. Optionally enable debug frame stats; record a video of recurring stalls.

Expected Result:

No increasing lag, duplicated sounds, missing enabled haptics, stale overlays, crashes or delayed touches. Debug FPS is a clue, not a release performance benchmark; use a profile/release candidate for measured performance claims.

Result:

- [ ] PASS
- [ ] FAIL
- [ ] BLOCKED

Notes:

_Not run. Record observations, variants and evidence here._

## Reporting FAIL / BLOCKED

Record test ID, phone model, Android version, app build/commit SHA, exact steps, actual result and expected result. Attach screenshot/video if it explains the problem. State whether the test used Daily Lab, timer skips or resource grants. BLOCKED means a prerequisite prevented execution; it does not mean the feature passed.

Optional developer evidence after reproducing:

```sh
adb logcat -d > echo-room-logcat.txt
adb shell settings --user current get system haptic_feedback_enabled
```

Review logs for personal data before sharing. A value of `0` indicates system touch haptics are disabled on devices exposing this setting; change through Android Settings and retest. A dispatch log is not proof the vibrator ran. No tester is required to collect logs to report a clear failure.

For formal runs, use [test-runs/README.md](test-runs/README.md); normal PRs may record test IDs/results directly in the PR. Never replace a hardware result with a CI status.

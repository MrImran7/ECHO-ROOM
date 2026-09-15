# Testing ECHO ROOM

Two layers protect the game: automated regression on every change, and a small physical-device pass for hardware and OS behavior. **CI PASS does not mean physical hardware was verified.** Physical results begin as NOT RUN.

## Automated layers and current coverage

Keep deterministic rules in Dart/Flutter tests. Do not manually recalculate scores or replay every migration on every PR.

| Feature | Unit | Widget | Device integration | Physical |
| --- | --- | --- | --- | --- |
| Scoring / stars | scoring_test; exact values and boundaries | Result presentation | Not configured | Visual smoke only |
| Progression / lives / rewards | progress_test, progression_regression_test; replay bests, unlocks, Level 20, rewards once | result_robustness_test | Not configured | Flow / presentation smoke |
| Persistence / migration / reset | controller_test, progression_regression_test, onboarding_test | Restart with recreated providers | Not configured | Real process death / upgrade |
| Gameplay state / timers / hitboxes | session_test, chapter_test | app_test runs real Flame GameWidget through Home, gameplay and result | Not configured | Touch, blackout, frame pacing |
| Daily selection / streak / immutable result | daily_test, daily_regression_test, daily_hardening_test | daily_screen_test, daily_ux_test | Not configured | Local date / restart sanity |
| Onboarding / navigation / settings | onboarding_test, controller_test | onboarding_test, result_robustness_test; narrow / large text / rapid actions | Not configured | OS Back, TalkBack, first-session smoke |
| Audio / haptics | feel_test, haptics_test; requests, settings, failures, lifecycle | Service wiring exercised | Not configured | REQUIRED: audible / felt response |
| Reduced motion / layouts | Presentation state tests | feel_test, daily_ux_test, onboarding_test | Not configured | System accessibility and safe areas |

Names above refer to `test/<name>.dart`. `test/test_support.dart` supplies isolated repositories. The flat test layout stays: moving files adds no coverage. The baseline before this documentation pass is 170 tests; use the final `flutter test` log for the current count, because parameterized tests cannot be counted by searching source lines.

Unit tests own score/streak calculations, serialization, old saves, state transitions and idempotence. Widget tests own navigation, buttons, settings, onboarding, result layouts and text scaling. Existing multi-screen and provider-recreation tests run inside the widget/test host; they are not installed-app integration tests.

`integration_test/` currently contains only a README. Although the SDK dependency is declared, there is **no runnable device integration target or CI integration invocation**. Do not run a nonexistent target or report integration PASS. When a real test is added, choose a small deterministic multi-screen flow that adds coverage beyond `app_test.dart`, document its exact target/device command here, and add CI only when emulator infrastructure is reliable. Real integration execution requires a supported emulator/simulator/device. Process recreation in controller tests does not prove OS process-kill recovery.

## What GitHub Actions runs

Source of truth: [validate.yml](../.github/workflows/validate.yml) and [validate.py](../tool/validate.py).

The `Validate Echo Room` workflow triggers automatically on `push`, `pull_request`, and manually via `workflow_dispatch`. A developer does not need to launch a script after pushing. Push and PR runs may both appear; check the run's commit, not an older green result.

| Job / stage | Actual command or behavior | Evidence |
| --- | --- | --- |
| Android setup | Ubuntu, Java 17, stable Flutter, Pillow | Setup step logs |
| Android validation | `python3 tool/validate.py` | Validation step log |
| Format | `dart format .` | Formatter output; edits files in the runner |
| Host generation | `python3 tool/bootstrap.py --skip-pub` | Bootstrap output |
| Dependencies | `flutter pub get` | PASS/FAIL in report and log |
| Static analysis | `flutter analyze` | PASS/FAIL in report and log |
| Unit/widget/Flame flows | `flutter test` | Test names, count and result |
| Android package | `flutter build apk --debug` | Build result / APK artifact |
| iOS setup and simulator build | `python3 tool/bootstrap.py`, then `flutter build ios --simulator --debug` on macOS | Separate iOS job log |
| Device integration / physical | Not executed | NOT RUN, never inferred from builds |

The iOS job builds a simulator app; it does not execute simulator tests. The Android job uploads `echo-room-validation` (`validation-results.json`), `echo-room-debug-apk`, and scene-review PNGs as `chapter-1-scene-review` when available. PNGs are automated room-render evidence, not phone screenshots.

The JSON format remains `recordedAt` plus `checks` containing command/status and exitCode or blocked reason. Formatting and bootstrap are outside its checks array: inspect their logs too. An early failure may leave no new report; absence is not PASS. No physical result is written by CI.

Formatting currently modifies files rather than enforcing a no-diff check. The existing formatter-commit step only applies to push runs on gameplay-core, chapter-1, game-feel and progression feature branches; it does not commit formatting on onboarding-polish. Review local formatting before committing. This QA pass does not change that workflow or weaken any gate.

## Run locally

From the repository root, install the stable Flutter SDK on PATH, Python 3 with Pillow, Java 17, and a configured/licensed Android SDK. Native host projects are generated by bootstrap and must not be committed. See the root README for running the app.

```sh
# Same full Android-side validation as CI (includes formatting/bootstrap):
python3 tool/validate.py

# Tests only, after resolving dependencies:
flutter pub get
flutter test

# Single file (replace with a real test filename):
flutter test test/scoring_test.dart
# General form: flutter test test/<file>.dart

# Existing multi-screen widget flow, no phone/emulator needed:
flutter test test/app_test.dart
# State recreation / persistence tests:
flutter test test/controller_test.dart
```

Individual gates, after `python3 tool/bootstrap.py` on a fresh checkout:

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

On macOS with Xcode and its simulator tooling, reproduce the separate iOS job:

```sh
python3 tool/bootstrap.py
flutter build ios --simulator --debug
```

No integration-test command is currently applicable: no Dart target exists in `integration_test/`. SDK/build failures are BLOCKED/FAIL, never successful validation. Review `git diff` after formatting; do not commit generated hosts, build output or local reports.

## Physical layer

Use [PHYSICAL_TEST_PLAN.md](PHYSICAL_TEST_PLAN.md): 15-case routine smoke, feature-specific cases, and the exact PR #6 onboarding selection. Execute broader regression for releases or affected features, not every business rule manually. Use a matching build SHA. P0 cases applicable to a change must pass before merge/release; unexecuted cases stay NOT RUN, and unavailable prerequisites are BLOCKED. Debug-only scenarios cannot prove release UI absence: audit release guards and spot-check a release candidate separately.

Stable IDs are permanent references: never reuse a retired ID for another behavior. Add new IDs when a feature adds a hardware concern; revise steps when labels change. Formal run records are optional; see [test-runs/README.md](test-runs/README.md).

## When adding a new feature

Every PR must answer:

1. What logic changed?
2. Which automated tests were added/updated (or why existing coverage suffices)?
3. Does this feature require physical-device verification?
4. If yes, which physical test IDs apply, and what is their actual status?
5. Does `docs/PHYSICAL_TEST_PLAN.md` need updating?

Prefer fixed clocks, isolated repositories, explicit state transitions and awaited writes. Add regressions for bugs before expanding manual checklists. Keep hardware assertions out of mocks: dispatching a haptic request is not proof of vibration. Update this guide whenever workflow commands, test targets or coverage responsibilities change.

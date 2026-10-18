# Optional physical execution records

For a formal/release run, copy the selected cases from ../PHYSICAL_TEST_PLAN.md into a file named `YYYY-MM-DD_android_<device>_<commit>.md` (for example `2026-09-15_android_pixel8_ab12cd3.md`). Normal PRs may record the same information in the PR instead; a committed report is not required.

Start with tester, date, device model, Android version, build/commit SHA, APK source, fresh/upgrade install, signature compatibility, system text/motion/audio/haptic settings, and any debug overrides. Link the matching automated run separately.

Leave every result NOT RUN until executed. Select PASS, FAIL or BLOCKED per test ID; record actual observations and evidence. Record omitted variants as NOT RUN, never silently PASS the full case. For failures include exact reproduction steps and screenshots/video/logcat where useful. Do not include personal device data or unrelated logs. CI must not populate these results.

Retest against a new SHA in a new record or clearly identified section; do not erase the original failure. Stable test IDs allow comparisons across builds.

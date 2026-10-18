# Device integration tests

No runnable Dart integration tests exist here yet. The SDK dependency alone does not create tests.

`flutter test test/app_test.dart` exercises the real Flame GameWidget in a multi-screen widget flow. `flutter test test/controller_test.dart` covers repository/provider recreation. Both are included in the normal `flutter test` CI gate; neither runs an installed app on a device.

There is currently no device integration command or emulator test job to report as passing. Add a target only for a concrete coverage gap, document its exact command and device prerequisites, and avoid duplicating every unit/widget assertion.

See [the testing strategy](../docs/TESTING.md) and [physical QA plan](../docs/PHYSICAL_TEST_PLAN.md).

abstract interface class AdService {
  Future<bool> showRewarded({required String placement});
}

/// No SDK, network calls or forced advertising in this version.
class MockAdService implements AdService {
  @override
  Future<bool> showRewarded({required String placement}) async => false;
}

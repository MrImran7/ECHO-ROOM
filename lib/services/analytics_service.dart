import 'package:flutter/foundation.dart';

abstract interface class AnalyticsService {
  void log(String event, [Map<String, Object?> parameters = const {}]);
}

class DebugAnalyticsService implements AnalyticsService {
  @override
  void log(String event, [Map<String, Object?> parameters = const {}]) {
    if (kDebugMode) debugPrint('[Echo Room] $event $parameters');
  }
}

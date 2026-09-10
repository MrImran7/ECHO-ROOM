import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress.dart';
import '../models/scene.dart';

abstract interface class ProgressRepository {
  Future<Progress> load();
  Future<void> save(Progress progress);
}

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository({SharedPreferencesAsync? preferences})
    : _prefs = preferences ?? SharedPreferencesAsync();
  final SharedPreferencesAsync _prefs;
  static const key = 'echo_room.progress.v1';
  Future<void> _pending = Future.value();
  @override
  Future<Progress> load() async {
    final raw = await _prefs.getString(key);
    if (raw == null) return Progress();
    // Do not silently destroy a damaged/newer save. Bootstrap shows recovery UI.
    return Progress.fromJson(jsonDecode(raw) as Json);
  }

  @override
  Future<void> save(Progress progress) {
    final bytes = jsonEncode(progress.toJson());
    final write = _pending.then((_) => _prefs.setString(key, bytes));
    // Serialize writes so an older lifecycle checkpoint cannot overwrite a win.
    _pending = write.catchError((Object _) {});
    return write;
  }
}

class MemoryProgressRepository implements ProgressRepository {
  Progress value = Progress();
  @override
  Future<Progress> load() async => Progress.fromJson(value.toJson());
  @override
  Future<void> save(Progress progress) async {
    value = Progress.fromJson(progress.toJson());
  }
}

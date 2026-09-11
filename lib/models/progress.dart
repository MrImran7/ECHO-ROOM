import '../core/config.dart';
import 'scene.dart';

class UserSettings {
  const UserSettings({
    this.music = true,
    this.sound = true,
    this.haptics = true,
  });
  final bool music, sound, haptics;
  factory UserSettings.fromJson(Json j) => UserSettings(
    music: j['music'] as bool? ?? true,
    sound: j['sound'] as bool? ?? true,
    haptics: j['haptics'] as bool? ?? true,
  );
  Json toJson() => {'music': music, 'sound': sound, 'haptics': haptics};
  UserSettings copyWith({bool? music, bool? sound, bool? haptics}) =>
      UserSettings(
        music: music ?? this.music,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
      );
}

class LevelRecord {
  const LevelRecord({this.score = 0, this.stars = 0, this.bestTime = 0});
  final int score, stars;
  final double bestTime;
  factory LevelRecord.fromJson(Json j) => LevelRecord(
    score: j['score'] as int? ?? 0,
    stars: j['stars'] as int? ?? 0,
    bestTime: number(j['bestTime']),
  );
  Json toJson() => {'score': score, 'stars': stars, 'bestTime': bestTime};
}

class DailyRecord {
  const DailyRecord({
    required this.levelId,
    this.status = 'started',
    this.puzzleVersion = 1,
    this.mistakes = 0,
    this.hintsUsed = 0,
    this.time = 0,
    this.score = 0,
  });
  final int levelId, score, puzzleVersion, mistakes, hintsUsed;
  bool get finalized => status == 'won' || status == 'lost';
  int get responseTimeMs => (time * 1000).round();
  String get puzzleId => 'apartment-$levelId';
  final String status;
  final double time;
  factory DailyRecord.fromJson(Json j) => DailyRecord(
    levelId: j['levelId'] as int,
    status: j['status'] as String? ?? 'started',
    puzzleVersion: j['puzzleVersion'] as int? ?? 1,
    mistakes: j['mistakes'] as int? ?? 0,
    hintsUsed: j['hintsUsed'] as int? ?? 0,
    time: j['responseTimeMs'] is int
        ? (j['responseTimeMs'] as int) / 1000
        : number(j['time']),
    score: j['score'] as int? ?? 0,
  );
  Json toJson() => {
    'levelId': levelId,
    'status': status,
    'puzzleVersion': puzzleVersion,
    'puzzleId': puzzleId,
    'responseTimeMs': responseTimeMs,
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'time': time,
    'score': score,
  };
}

/// Versioned, immutable save envelope. Collections are copied on construction.
class Progress {
  Progress({
    this.highestLevel = 1,
    this.lives = GameConfig.maxLives,
    this.lifeAnchor,
    this.hints = GameConfig.initialHints,
    this.streak = 0,
    this.bestStreak = 0,
    this.correctAnswers = 0,
    this.wrongTaps = 0,
    this.hintsUsed = 0,
    this.dailyStreak = 0,
    this.bestDailyStreak = 0,
    this.lastDailyWin,
    this.settings = const UserSettings(),
    Map<int, LevelRecord> levels = const {},
    Map<String, DailyRecord> daily = const {},
    Set<String> achievements = const {},
    Set<String> collectibles = const {},
    Set<int> perfectLevels = const {},
    Set<int> unassistedLevels = const {},
    List<String> completedRuns = const [],
    this.activeSession,
  }) : levels = Map.unmodifiable(levels),
       daily = Map.unmodifiable(daily),
       achievements = Set.unmodifiable(achievements),
       collectibles = Set.unmodifiable(collectibles),
       perfectLevels = Set.unmodifiable(perfectLevels),
       unassistedLevels = Set.unmodifiable(unassistedLevels),
       completedRuns = List.unmodifiable(completedRuns);
  final int highestLevel,
      lives,
      hints,
      streak,
      bestStreak,
      correctAnswers,
      wrongTaps,
      hintsUsed,
      dailyStreak,
      bestDailyStreak;
  final DateTime? lifeAnchor;
  final String? lastDailyWin;
  final UserSettings settings;
  final Map<int, LevelRecord> levels;
  final Map<String, DailyRecord> daily;
  final Set<String> achievements, collectibles;
  final Set<int> perfectLevels, unassistedLevels;
  final List<String> completedRuns;
  final Json? activeSession;
  factory Progress.fromJson(Json j) {
    if ((j['version'] as int? ?? 1) > 1)
      throw const FormatException('Save is from a newer version.');
    return Progress(
      highestLevel: j['highestLevel'] as int? ?? 1,
      lives: j['lives'] as int? ?? GameConfig.maxLives,
      lifeAnchor: DateTime.tryParse(j['lifeAnchor'] as String? ?? ''),
      hints: j['hints'] as int? ?? GameConfig.initialHints,
      streak: j['streak'] as int? ?? 0,
      bestStreak: j['bestStreak'] as int? ?? 0,
      correctAnswers:
          j['correctAnswers'] as int? ?? (j['levels'] as Json? ?? {}).length,
      wrongTaps: j['wrongTaps'] as int? ?? 0,
      hintsUsed: j['hintsUsed'] as int? ?? 0,
      dailyStreak: j['dailyStreak'] as int? ?? 0,
      bestDailyStreak: j['bestDailyStreak'] as int? ?? 0,
      lastDailyWin: j['lastDailyWin'] as String?,
      settings: UserSettings.fromJson(j['settings'] as Json? ?? {}),
      levels: (j['levels'] as Json? ?? {}).map(
        (k, v) => MapEntry(int.parse(k), LevelRecord.fromJson(v as Json)),
      ),
      daily: (j['daily'] as Json? ?? {}).map(
        (k, v) => MapEntry(k, DailyRecord.fromJson(v as Json)),
      ),
      achievements: (j['achievements'] as List<dynamic>? ?? [])
          .cast<String>()
          .toSet(),
      collectibles: (j['collectibles'] as List<dynamic>? ?? [])
          .cast<String>()
          .toSet(),
      perfectLevels: (j['perfectLevels'] as List<dynamic>? ?? [])
          .cast<int>()
          .toSet(),
      unassistedLevels: (j['unassistedLevels'] as List<dynamic>? ?? [])
          .cast<int>()
          .toSet(),
      completedRuns: (j['completedRuns'] as List<dynamic>? ?? [])
          .cast<String>(),
      activeSession: j['activeSession'] as Json?,
    );
  }
  Json toJson() => {
    'version': 1,
    'highestLevel': highestLevel,
    'lives': lives,
    'lifeAnchor': lifeAnchor?.toIso8601String(),
    'hints': hints,
    'streak': streak,
    'bestStreak': bestStreak,
    'correctAnswers': correctAnswers,
    'wrongTaps': wrongTaps,
    'hintsUsed': hintsUsed,
    'dailyStreak': dailyStreak,
    'bestDailyStreak': bestDailyStreak,
    'lastDailyWin': lastDailyWin,
    'settings': settings.toJson(),
    'levels': levels.map((k, v) => MapEntry('$k', v.toJson())),
    'daily': daily.map((k, v) => MapEntry(k, v.toJson())),
    'achievements': achievements.toList(),
    'collectibles': collectibles.toList(),
    'perfectLevels': perfectLevels.toList(),
    'unassistedLevels': unassistedLevels.toList(),
    'completedRuns': completedRuns,
    'activeSession': activeSession,
  };

  /// Derived from records so replays cannot inflate chapter mastery.
  int roomsCompleted(int count) =>
      levels.keys.where((id) => id >= 1 && id <= count).length;
  int totalStars(int count) => levels.entries
      .where((entry) => entry.key >= 1 && entry.key <= count)
      .fold(0, (sum, entry) => sum + entry.value.stars);
  bool chapterComplete(int count) => roomsCompleted(count) == count;
  int completionPercent(int count) =>
      count == 0 ? 0 : (100 * roomsCompleted(count) / count).round();
  double? get bestResponseTime => levels.values.isEmpty
      ? null
      : levels.values.map((r) => r.bestTime).reduce((a, b) => a < b ? a : b);

  /// Patch through the schema codec: one serialization contract for persistence
  /// and updates. Progress is small; writes occur at decisions, never per frame.
  Progress patch(Json values) => Progress.fromJson({...toJson(), ...values});
}

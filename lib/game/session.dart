import 'dart:math' as math;

import '../core/config.dart';
import '../models/scene.dart';
import 'hit_test.dart';

enum GamePhase {
  loading,
  intro,
  countdown,
  observing,
  flicker,
  blackout,
  answering,
  incorrect,
  correct,
  timedOut,
  won,
  lost,
  paused,
}

enum LossReason { timeout, attempts, abandoned }

enum TapResult { ignored, wrong, correct, failed }

/// One deterministic clock, advanced only by the owning Flame instance.
/// Presentation and persistence observe these rules; they cannot assign phases.
class GameSession {
  GameSession({
    required this.level,
    required Room room,
    required this.runId,
    this.dailyDate,
    this.skipObservation = false,
    this.skipCountdown = false,
  }) : original = RoomState(room.objects),
       changed = ChangeRegistry().apply(RoomState(room.objects), level.changes),
       targets = Set.unmodifiable(level.targets);
  final LevelDefinition level;
  final RoomState original, changed;
  final Set<String> targets;
  late final HitTester hitTester = HitTester(original, changed, targets);
  final String runId;
  final String? dailyDate;
  final bool skipObservation, skipCountdown;
  GamePhase _phase = GamePhase.loading;
  GamePhase? _resumePhase;
  GamePhase get phase => _phase;
  GamePhase get activePhase => _resumePhase ?? _phase;
  LossReason? _lossReason;
  LossReason? get lossReason => _lossReason;
  double _phaseElapsed = 0, _answerElapsed = 0;
  double get phaseElapsed => _phaseElapsed;
  double get answerElapsed => _answerElapsed;
  double cooldown = 0, feedbackRemaining = 0, hintRemaining = 0;
  int _mistakes = 0, _hints = 0;
  int get mistakes => _mistakes;
  int get hints => _hints;
  String? lastTapped;
  bool get paused => _phase == GamePhase.paused;
  bool get finished => _phase == GamePhase.won || _phase == GamePhase.lost;
  bool get resolved =>
      const {
        GamePhase.correct,
        GamePhase.timedOut,
        GamePhase.won,
        GamePhase.lost,
      }.contains(activePhase) ||
      (activePhase == GamePhase.incorrect && attemptsLeft == 0);
  bool get isChanged => const {
    GamePhase.answering,
    GamePhase.incorrect,
    GamePhase.correct,
    GamePhase.timedOut,
    GamePhase.won,
    GamePhase.lost,
  }.contains(activePhase);
  bool get revealAnswer =>
      activePhase == GamePhase.correct ||
      activePhase == GamePhase.timedOut ||
      activePhase == GamePhase.won ||
      activePhase == GamePhase.lost ||
      (activePhase == GamePhase.incorrect && attemptsLeft == 0);
  RoomState get visibleRoom => isChanged ? changed : original;
  double get duration => _durationFor(activePhase);
  double _durationFor(GamePhase phase) => switch (phase) {
    GamePhase.intro => GameConfig.introSeconds,
    GamePhase.countdown => GameConfig.countdownSeconds,
    GamePhase.observing =>
      skipObservation
          ? GameConfig.skippedObservationSeconds
          : level.observationDuration,
    GamePhase.flicker => GameConfig.flickerSeconds,
    GamePhase.blackout => GameConfig.blackoutSeconds,
    GamePhase.answering => level.answerDuration,
    GamePhase.incorrect => GameConfig.wrongFeedbackSeconds,
    GamePhase.correct => GameConfig.correctFeedbackSeconds,
    GamePhase.timedOut => GameConfig.timeoutRevealSeconds,
    _ => 0,
  };
  double get remaining => math.max(
    0,
    activePhase == GamePhase.answering || activePhase == GamePhase.incorrect
        ? level.answerDuration - _answerElapsed
        : duration - _phaseElapsed,
  );
  int get attemptsLeft =>
      math.max(0, (dailyDate == null ? level.attempts : 1) - _mistakes);

  void ready() {
    if (_phase == GamePhase.loading) _transition(GamePhase.intro);
    if (paused && _resumePhase == GamePhase.loading)
      _resumePhase = GamePhase.intro;
  }

  void pause() {
    if (paused || finished) return;
    _resumePhase = _phase;
    _phase = GamePhase.paused;
  }

  void resume() {
    if (!paused) return;
    _phase = _resumePhase!;
    _resumePhase = null;
  }

  void abandon() {
    if (finished || resolved) return;
    _resumePhase = null;
    _lossReason = LossReason.abandoned;
    _transition(GamePhase.lost);
  }

  void _transition(GamePhase next) {
    _phase = next;
    _phaseElapsed = 0;
  }

  void advance(double dt) {
    if (paused ||
        finished ||
        _phase == GamePhase.loading ||
        !dt.isFinite ||
        dt <= 0)
      return;
    var rest = dt;
    while (rest > 0 && !finished) {
      var untilTransition = math.max(0.0, duration - _phaseElapsed);
      final answering =
          _phase == GamePhase.answering ||
          (_phase == GamePhase.incorrect && attemptsLeft > 0);
      if (answering)
        untilTransition = math.min(
          untilTransition,
          level.answerDuration - _answerElapsed,
        );
      final step = math.min(rest, untilTransition);
      _phaseElapsed += step;
      if (answering)
        _answerElapsed = math.min(level.answerDuration, _answerElapsed + step);
      cooldown = math.max(0, cooldown - step);
      feedbackRemaining = math.max(0, feedbackRemaining - step);
      hintRemaining = math.max(0, hintRemaining - step);
      rest -= step;
      if (answering && _answerElapsed >= level.answerDuration - .000001) {
        _answerElapsed = level.answerDuration;
        _lossReason = LossReason.timeout;
        _transition(GamePhase.timedOut);
      } else if (_phaseElapsed >= duration - .000001) {
        switch (_phase) {
          case GamePhase.intro:
            _transition(
              skipCountdown ? GamePhase.observing : GamePhase.countdown,
            );
          case GamePhase.countdown:
            _transition(GamePhase.observing);
          case GamePhase.observing:
            _transition(GamePhase.flicker);
          case GamePhase.flicker:
            _transition(GamePhase.blackout);
          case GamePhase.blackout:
            _transition(GamePhase.answering);
          case GamePhase.incorrect:
            _transition(
              attemptsLeft == 0 ? GamePhase.lost : GamePhase.answering,
            );
          case GamePhase.correct:
            _transition(GamePhase.won);
          case GamePhase.timedOut:
            _transition(GamePhase.lost);
          default:
            return;
        }
      } else {
        break;
      }
    }
  }

  TapResult tap(double x, double y, {double padding = .025}) {
    if (_phase != GamePhase.answering ||
        cooldown > 0 ||
        !x.isFinite ||
        !y.isFinite ||
        !padding.isFinite ||
        padding < 0 ||
        x < 0 ||
        x > 1 ||
        y < 0 ||
        y > 1)
      return TapResult.ignored;
    final id = hitTester.resolve(x, y, minimumPadding: padding);
    if (id == null) return TapResult.ignored;
    lastTapped = id;
    cooldown = GameConfig.tapCooldown;
    if (targets.contains(id)) {
      feedbackRemaining = GameConfig.correctFeedbackSeconds;
      _transition(GamePhase.correct);
      return TapResult.correct;
    }
    _mistakes++;
    feedbackRemaining = GameConfig.wrongFeedbackSeconds;
    if (attemptsLeft == 0) _lossReason = LossReason.attempts;
    _transition(GamePhase.incorrect);
    return attemptsLeft == 0 ? TapResult.failed : TapResult.wrong;
  }

  bool useHint() {
    if (_phase != GamePhase.answering || _hints >= 3 || dailyDate != null)
      return false;
    _hints++;
    hintRemaining = _hints == 3 ? remaining : GameConfig.hintPulseSeconds;
    return true;
  }

  Json toJson() => {
    'levelId': level.levelId,
    'runId': runId,
    'dailyDate': dailyDate,
    'phase': activePhase.name,
    'phaseElapsed': _phaseElapsed,
    'answerElapsed': _answerElapsed,
    'mistakes': _mistakes,
    'hints': _hints,
    'skipObservation': skipObservation,
    'skipCountdown': skipCountdown,
    'cooldown': cooldown,
    'feedbackRemaining': feedbackRemaining,
    'hintRemaining': hintRemaining,
    'lastTapped': lastTapped,
    'lossReason': _lossReason?.name,
  };

  void restore(Json j) {
    final nextPhase = GamePhase.values.firstWhere(
      (p) => p.name == j['phase'],
      orElse: () => throw const FormatException('Unknown saved game phase.'),
    );
    final nextPhaseElapsed = number(j['phaseElapsed']);
    final nextAnswerElapsed = number(j['answerElapsed']);
    final nextMistakes = j['mistakes'], nextHints = j['hints'];
    final nextCooldown = number(j['cooldown']),
        nextFeedback = number(j['feedbackRemaining']);
    final nextHintTime = number(
      j['hintRemaining'],
      nextHints == 3
          ? math.max(0, level.answerDuration - nextAnswerElapsed)
          : 0,
    );
    final nextTapped = j['lastTapped'] as String?;
    final reason = j['lossReason'] as String?;
    final terminal = nextPhase == GamePhase.won || nextPhase == GamePhase.lost;
    if (j['levelId'] != level.levelId ||
        j['runId'] != runId ||
        j['dailyDate'] != dailyDate ||
        nextPhase == GamePhase.paused ||
        [
          nextPhaseElapsed,
          nextAnswerElapsed,
          nextCooldown,
          nextFeedback,
          nextHintTime,
        ].any((v) => !v.isFinite || v < 0) ||
        nextAnswerElapsed > level.answerDuration ||
        (!terminal && nextPhaseElapsed > _durationFor(nextPhase)) ||
        nextMistakes is! int ||
        nextMistakes < 0 ||
        nextMistakes > (dailyDate == null ? level.attempts : 1) ||
        nextHints is! int ||
        nextHints < 0 ||
        nextHints > 3 ||
        (dailyDate != null && nextHints != 0) ||
        (reason != null && !LossReason.values.any((r) => r.name == reason)) ||
        (nextTapped != null &&
            !original.objects.any((o) => o.id == nextTapped))) {
      throw const FormatException('The saved room contains invalid values.');
    }
    _phase = nextPhase;
    _phaseElapsed = nextPhaseElapsed;
    _answerElapsed = nextAnswerElapsed;
    _mistakes = nextMistakes;
    _hints = nextHints;
    cooldown = nextCooldown;
    feedbackRemaining = nextFeedback;
    hintRemaining = nextHintTime;
    lastTapped = nextTapped;
    _lossReason = reason == null ? null : LossReason.values.byName(reason);
    if (!terminal && nextPhase != GamePhase.loading) pause();
  }
}

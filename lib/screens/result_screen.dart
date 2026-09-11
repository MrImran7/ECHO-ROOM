import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../achievements/definitions.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../collection/definitions.dart';
import '../game/session.dart';
import '../core/config.dart';
import '../services/audio_service.dart';
import '../services/progression_service.dart';
import '../widgets/common.dart';
import '../game/session_controller.dart';
import 'gameplay_screen.dart';
import 'chapters_screen.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({
    required this.session,
    required this.completion,
    super.key,
  });
  final GameSession session;
  final Completion completion;
  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  late final HapticsService _haptics;
  bool _leaving = false;
  @override
  void dispose() {
    _haptics.cancelPending();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _haptics = ref.read(hapticsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = widget.session;
      // One result cue: milestone wins priority over story and completion.
      // Loss already received its feedback in the session controller.
      if (s.phase != GamePhase.won) return;
      final milestone =
          widget.completion.streakLabel != null ||
          widget.completion.newAchievements.isNotEmpty;
      ref
          .read(audioProvider)
          .cue(
            milestone
                ? SoundCue.streak
                : s.level.storyText.isNotEmpty
                ? SoundCue.mystery
                : SoundCue.complete,
          );
      unawaited(milestone ? _haptics.celebrate() : _haptics.complete());
    });
  }

  Future<void> _play(int id) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _haptics.cancelPending();
    try {
      await ref.read(sessionProvider.notifier).start(id);
      if (!mounted) return;
      // Keep the lock through route replacement; other result actions stay off.
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => const GameplayScreen()),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _leaving = false);
      rethrow;
    }
  }

  Future<void> _home() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _haptics.cancelPending();
    Navigator.of(context).pop();
  }

  Future<void> _chapters() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    _haptics.cancelPending();
    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => const ChaptersScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session,
        done = widget.completion,
        p = ref.watch(profileProvider);
    final won = s.phase == GamePhase.won, daily = s.dailyDate != null;
    final count = ref.read(catalogProvider).requireValue.levels.length;
    final chapterFinished =
        won && !daily && s.level.levelId == count && p.chapterComplete(count);
    return PopScope<void>(
      canPop: !_leaving,
      child: Scaffold(
        appBar: AppBar(title: Text(daily ? 'DAILY ROOM' : 'THE APARTMENT')),
        body: PageBody(
          children: [
            const SizedBox(height: 24),
            Icon(
              won
                  ? Icons.check_circle_outline_rounded
                  : Icons.nightlight_outlined,
              color: EchoTheme.gold,
              size: 48,
            ),
            const SizedBox(height: 22),
            Eyebrow(won ? 'ROOM COMPLETE' : 'ROOM UNRESOLVED'),
            const SizedBox(height: 12),
            Text(
              won ? 'Nothing escapes you.' : 'Some details stay hidden.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .9, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(
                      milliseconds: GameConfig.starRevealMilliseconds,
                    ),
              curve: Curves.easeOutCubic,
              child: Center(child: Stars(done.score.stars, size: 40)),
              builder: (_, value, child) =>
                  Transform.scale(scale: value, child: child),
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: done.score.total.toDouble()),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(
                      milliseconds: GameConfig.scoreAnimationMilliseconds,
                    ),
              builder: (_, value, _) => FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.round().toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 66,
                    fontWeight: FontWeight.w300,
                    color: EchoTheme.cream,
                  ),
                ),
              ),
            ),
            const Eyebrow('POINTS'),
            if (done.newBestScore ||
                done.newBestTime ||
                done.newStarRecord) ...[
              const SizedBox(height: 12),
              Text(
                [
                  if (done.newBestScore) 'NEW BEST SCORE',
                  if (done.newBestTime) 'NEW BEST TIME',
                  if (done.newStarRecord) 'NEW STAR RECORD',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(color: EchoTheme.gold, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            Panel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Stat(
                        '${s.answerElapsed.toStringAsFixed(2)}s',
                        'DETECTION TIME',
                      ),
                      Stat(
                        '${won ? (100 / (s.mistakes + 1)).round() : 0}%',
                        'ACCURACY',
                      ),
                      Stat('${s.hints}', 'HINTS USED'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'BEST ${daily ? p.daily[s.dailyDate]?.score ?? 0 : p.levels[s.level.levelId]?.score ?? 0}   ·   STREAK ×${done.score.multiplier}',
                    style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      color: EchoTheme.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            if (!daily && won && s.level.levelId < count) ...[
              ActionButton(
                'NEXT ROOM',
                icon: Icons.arrow_forward,
                onPressed: _leaving ? null : () => _play(s.level.levelId + 1),
              ),
              const SizedBox(height: 10),
            ],
            if (chapterFinished) ...[
              ActionButton(
                'REPLAY LEVELS',
                icon: Icons.grid_view_rounded,
                onPressed: _leaving ? null : _chapters,
              ),
              const SizedBox(height: 10),
            ],
            if (!daily) ...[
              ActionButton(
                won ? 'REPLAY' : 'TRY AGAIN',
                secondary: won,
                onPressed: _leaving ? null : () => _play(s.level.levelId),
              ),
              const SizedBox(height: 10),
            ],
            ActionButton(
              'HOME',
              secondary: true,
              onPressed: _leaving ? null : _home,
            ),
            if (daily) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Stat('${p.dailyStreak}', 'DAILY STREAK'),
                  Stat('${p.bestDailyStreak}', 'BEST DAILY STREAK'),
                ],
              ),
            ],
            if (done.hintsEarned > 0) ...[
              const SizedBox(height: 12),
              Eyebrow('+${done.hintsEarned} HINTS · CHAPTER MILESTONE'),
            ],
            if (done.streakLabel != null) ...[
              const SizedBox(height: 20),
              Eyebrow('${done.streakLabel} · ${p.streak} IN A ROW'),
            ],
            for (final a in achievements.where(
              (a) => done.newAchievements.contains(a.id),
            )) ...[
              const SizedBox(height: 12),
              Panel(
                child: Row(
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: EchoTheme.gold,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: const TextStyle(color: EchoTheme.cream),
                          ),
                          Text(
                            a.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            for (final item in collectibles.where(
              (c) => done.newCollectibles.contains(c.id),
            )) ...[
              const SizedBox(height: 12),
              Panel(
                child: Row(
                  children: [
                    ObjectArtwork(art: item.art),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '${item.name}\n${item.description}\n${item.condition}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (won && s.level.storyText.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '“${s.level.storyText}”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                  color: EchoTheme.gold,
                ),
              ),
            ],
            if (chapterFinished) ...[
              const SizedBox(height: 16),
              Panel(
                child: Column(
                  children: [
                    const Eyebrow('CHAPTER COMPLETE'),
                    const SizedBox(height: 12),
                    const Text('THE APARTMENT', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      '${p.totalStars(count)} / ${count * 3} ★ · ${p.completionPercent(count)}% complete',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${p.roomsCompleted(count)} rooms solved · Best streak ${p.bestStreak}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '${p.collectibles.length} / ${collectibles.length} mystery objects found',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The next door is not open. Yet.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

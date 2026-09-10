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
    await ref.read(sessionProvider.notifier).start(id);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(builder: (_) => const GameplayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session,
        done = widget.completion,
        p = ref.watch(profileProvider);
    final won = s.phase == GamePhase.won, daily = s.dailyDate != null;
    final count = ref.read(catalogProvider).requireValue.levels.length;
    return Scaffold(
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
                : const Duration(milliseconds: 300),
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
            builder: (_, value, _) => Text(
              value.round().toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 66,
                fontWeight: FontWeight.w300,
                color: EchoTheme.cream,
              ),
            ),
          ),
          const Eyebrow('POINTS'),
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
          if (daily) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Stat('${p.dailyStreak}', 'DAILY STREAK'),
                Stat('${p.bestDailyStreak}', 'BEST DAILY STREAK'),
              ],
            ),
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
          if (done.newCollectible != null) ...[
            const SizedBox(height: 12),
            Panel(
              child: Row(
                children: [
                  ObjectArtwork(
                    art: collectibles
                        .firstWhere((c) => c.id == done.newCollectible)
                        .art,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('A mystery object joined your collection.'),
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
          const SizedBox(height: 26),
          if (!daily && won && s.level.levelId < count) ...[
            ActionButton(
              'NEXT ROOM',
              icon: Icons.arrow_forward,
              onPressed: () => _play(s.level.levelId + 1),
            ),
            const SizedBox(height: 10),
          ],
          if (!daily) ...[
            ActionButton(
              won ? 'REPLAY' : 'TRY AGAIN',
              secondary: won,
              onPressed: () => _play(s.level.levelId),
            ),
            const SizedBox(height: 10),
          ],
          ActionButton(
            'HOME',
            secondary: true,
            onPressed: () async {
              Navigator.of(context).pop();
            },
          ),
          if (won && s.level.levelId == count && !daily) ...[
            const SizedBox(height: 16),
            const Text(
              'CHAPTER 1 COMPLETE\nThe next door is not open. Yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

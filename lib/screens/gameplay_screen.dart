import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/config.dart';
import '../game/session.dart';
import '../game/session_controller.dart';
import '../widgets/common.dart';
import '../widgets/game_viewport.dart';
import 'result_screen.dart';

class GameplayScreen extends ConsumerStatefulWidget {
  const GameplayScreen({super.key});
  @override
  ConsumerState<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends ConsumerState<GameplayScreen> {
  late final GameSession _session;
  late final Widget _viewport;
  bool _allowPop = false, _resultsQueued = false;
  @override
  void initState() {
    super.initState();
    final controller = ref.read(sessionProvider.notifier);
    _session = controller.game!;
    _viewport = GameViewport(
      session: _session,
      showHitboxes: GameConfig.debugTools && ref.read(debugProvider).hitboxes,
      onPause: controller.pause,
      onReady: () {
        if (identical(controller.game, _session)) controller.ready();
      },
      onTick: (dt) {
        if (identical(controller.game, _session)) controller.tick(dt);
      },
      onTap: (x, y, padding) {
        if (identical(controller.game, _session)) controller.tap(x, y, padding);
      },
    );
  }

  Future<void> _home() async {
    final c = ref.read(sessionProvider.notifier);
    if (_session.finished) {
      if (c.completion == null) await c.retrySave();
      if (c.completion == null) return;
    } else {
      c.pause();
      await c.checkpoint();
      if (c.error != null) return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _queueResults() {
    final c = ref.read(sessionProvider.notifier);
    if (_resultsQueued || !_session.finished || c.completion == null) return;
    _resultsQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        _resultsQueued = false;
        return;
      }
      unawaited(_results());
    });
  }

  Future<void> _results() async {
    final done = ref.read(sessionProvider.notifier).completion;
    if (done == null || !mounted) return;
    setState(() => _allowPop = true);
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) => ResultScreen(session: _session, completion: done),
      ),
    );
  }

  Future<void> _abandon() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this attempt?'),
        content: Text(
          _session.dailyDate == null
              ? 'This counts as a failure and uses a life when lives are enabled.'
              : 'Your one daily chance will be used.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP PLAYING'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('END ATTEMPT'),
          ),
        ],
      ),
    );
    if (end == true && mounted)
      await ref.read(sessionProvider.notifier).abandon();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (_, _) => _queueResults());
    ref.watch(sessionProvider);
    final c = ref.read(sessionProvider.notifier), s = _session;
    final hintBalance = ref.watch(profileProvider.select((p) => p.hints));
    final title = switch (s.phase) {
      GamePhase.loading => 'OPENING THE ROOM',
      GamePhase.intro ||
      GamePhase.countdown ||
      GamePhase.observing => 'REMEMBER EVERYTHING',
      GamePhase.flicker || GamePhase.blackout => 'SOMETHING IS CHANGING',
      GamePhase.answering => 'WHAT CHANGED?',
      GamePhase.incorrect => '✕ NOT THAT',
      GamePhase.correct || GamePhase.won => '✓ FOUND IT!',
      GamePhase.timedOut => 'TIME’S UP',
      GamePhase.lost =>
        s.lossReason == LossReason.timeout
            ? 'TIME’S UP'
            : 'THE ROOM KEPT ITS SECRET',
      GamePhase.paused => 'TAKE YOUR TIME',
    };
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (s.finished) {
            unawaited(_home());
          } else {
            c.pause();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: s.finished ? 'Home' : 'Pause',
            icon: Icon(s.finished ? Icons.close : Icons.pause_rounded),
            onPressed: s.finished ? _home : c.pause,
          ),
          title: Text(
            s.dailyDate == null
                ? 'ROOM ${s.level.levelId.toString().padLeft(2, '0')}'
                : 'DAILY ROOM',
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: s.paused || s.resolved || s.duration == 0
                                    ? 0
                                    : (s.remaining / s.duration).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                minHeight: 3,
                                backgroundColor: const Color(0xff344240),
                                color: EchoTheme.gold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              s.paused || s.resolved || s.duration == 0
                                  ? '—'
                                  : '${s.remaining.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                fontSize: 13,
                                color: EchoTheme.gold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 400 / 440,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _viewport,
                                if (s.phase == GamePhase.intro ||
                                    s.phase == GamePhase.countdown)
                                  IgnorePointer(
                                    child: ColoredBox(
                                      color: EchoTheme.background,
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                            milliseconds: GameConfig
                                                .transitionMilliseconds,
                                          ),
                                          child: Text(
                                            s.phase == GamePhase.countdown
                                                ? '${s.remaining.ceil().clamp(1, 3)}'
                                                : 'Remember\neverything.',
                                            key: ValueKey(
                                              '${s.phase}${s.remaining.ceil()}',
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize:
                                                  s.phase == GamePhase.countdown
                                                  ? 80
                                                  : 34,
                                              fontWeight: FontWeight.w300,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (s.paused)
                                  ColoredBox(
                                    color: EchoTheme.background,
                                    child: Center(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'The room can wait.',
                                              style: TextStyle(fontSize: 24),
                                            ),
                                            const SizedBox(height: 8),
                                            const Text('Your timer is paused.'),
                                            const SizedBox(height: 20),
                                            ActionButton(
                                              'RESUME',
                                              onPressed: () async {
                                                c.resume();
                                              },
                                            ),
                                            const SizedBox(height: 10),
                                            ActionButton(
                                              'SAVE & HOME',
                                              secondary: true,
                                              onPressed: _home,
                                            ),
                                            if (!s.resolved)
                                              TextButton(
                                                onPressed: _abandon,
                                                child: const Text(
                                                  'END ATTEMPT',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.error != null) ...[
                          Text(
                            c.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffefa59a),
                            ),
                          ),
                          TextButton(
                            onPressed: c.retrySave,
                            child: const Text('RETRY SAVE'),
                          ),
                        ],
                        if (s.finished)
                          ActionButton(
                            'VIEW RESULT',
                            onPressed: c.completion == null ? null : _results,
                          )
                        else if (s.resolved && !s.paused)
                          const Text(
                            'A small detail makes all the difference.',
                            textAlign: TextAlign.center,
                          )
                        else ...[
                          Text(
                            s.hints > 0 && s.hintRemaining > 0 && !s.paused
                                ? s.level.hints[s.hints - 1]
                                : s.phase == GamePhase.observing
                                ? 'Remember the room. A detail will change.'
                                : s.dailyDate != null
                                ? 'ONE CHANCE · NO HINTS'
                                : 'Tap what changed — even if it disappeared.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed:
                                      s.phase == GamePhase.answering &&
                                          s.hints < 3 &&
                                          s.dailyDate == null
                                      ? c.hint
                                      : null,
                                  icon: const Icon(
                                    Icons.lightbulb_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    s.hints == 3
                                        ? 'REVEALED'
                                        : 'HINT ${s.hints + 1} · ${GameConfig.hintCosts[math.min(s.hints, 2)]}',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${s.attemptsLeft} tries\n$hintBalance hints',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

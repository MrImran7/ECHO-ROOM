import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/config.dart';
import '../game/echo_game.dart';
import '../game/session.dart';
import '../models/scene.dart';
import 'common.dart';

/// Owns exactly one rendering clock. Replaced instances cannot tick a new run.
class GameViewport extends StatefulWidget {
  const GameViewport({
    required this.session,
    required this.onReady,
    required this.onTick,
    required this.onTap,
    required this.onPause,
    this.showHitboxes = false,
    super.key,
  });
  final GameSession session;
  final VoidCallback onReady, onPause;
  final void Function(double) onTick;
  final void Function(double, double, double) onTap;
  final bool showHitboxes;
  @override
  State<GameViewport> createState() => _GameViewportState();
}

class _GameViewportState extends State<GameViewport>
    with WidgetsBindingObserver {
  late EchoGame _game;
  bool _answerGesture = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = _createGame();
  }

  EchoGame _createGame() {
    late final EchoGame game;
    game = EchoGame(
      room: Room(
        id: widget.session.level.roomId,
        name: 'Room',
        objects: widget.session.original.objects,
      ),
      session: () => widget.session,
      showHitboxes: widget.showHitboxes,
      onReady: () {
        if (mounted && identical(_game, game)) widget.onReady();
      },
      onTick: (dt) {
        if (mounted && identical(_game, game)) widget.onTick(dt);
      },
    );
    return game;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _game.resumeEngine();
    } else {
      _answerGesture = false;
      widget.onPause();
      _game.pauseEngine();
    }
  }

  @override
  void dispose() {
    _game.pauseEngine();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _game.reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, bounds) {
        _game.hitPadding = math.max(
          .015,
          GameConfig.minimumTouchSize / 2 / bounds.maxWidth,
        );
        return Semantics(
          label:
              'Apartment scene. Tap the object that changed, or where it was.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) {
              _answerGesture = widget.session.phase == GamePhase.answering;
            },
            onTapCancel: () => _answerGesture = false,
            onTapUp: (event) {
              if (!_answerGesture) return;
              _answerGesture = false;
              widget.onTap(
                event.localPosition.dx / bounds.maxWidth,
                event.localPosition.dy / bounds.maxHeight,
                _game.hitPadding,
              );
            },
            child: GameWidget<EchoGame>(
              key: ObjectKey(_game),
              game: _game,
              loadingBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorBuilder: (context, error) => ColoredBox(
                color: const Color(0xff111a1b),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'The room could not be loaded.',
                          textAlign: TextAlign.center,
                        ),
                        if (GameConfig.debugTools)
                          Text(
                            '$error',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 16),
                        ActionButton(
                          'RETRY ROOM',
                          onPressed: () async {
                            _game.pauseEngine();
                            setState(() => _game = _createGame());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

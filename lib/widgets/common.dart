import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app/theme.dart';
import '../game/room_art.dart';
import '../models/scene.dart';

class ActionButton extends StatefulWidget {
  const ActionButton(
    this.label, {
    required this.onPressed,
    this.icon,
    this.secondary = false,
    super.key,
  });
  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool secondary;
  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _busy = false;
  final _states = WidgetStatesController();
  @override
  void initState() {
    super.initState();
    _states.addListener(_pressedChanged);
  }
  void _pressedChanged() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() {}); });
    } else if (mounted) {
      setState(() {});
    }
  }
  @override
  void dispose() {
    _states.removeListener(_pressedChanged);
    _states.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_busy)
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (widget.icon != null)
          Icon(widget.icon, size: 19),
        if (_busy || widget.icon != null) const SizedBox(width: 12),
        Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
      ],
    );
    Future<void> press() async {
      if (_busy || widget.onPressed == null) return;
      setState(() => _busy = true);
      try {
        await widget.onPressed!();
      } catch (e) {
        if (context.mounted)
          showMessage(context, e.toString().replaceFirst('Bad state: ', ''));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return AnimatedScale(
      scale: _states.value.contains(WidgetState.pressed) ? .98 : 1,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero :
          const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: SizedBox(
      width: double.infinity,
      child: widget.secondary
          ? OutlinedButton(
              statesController: _states,
              onPressed: _busy || widget.onPressed == null ? null : press,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 19,
                  horizontal: 14,
                ),
                foregroundColor: EchoTheme.cream,
                side: const BorderSide(color: Color(0xff42504a)),
                shape: shape,
              ),
              child: child,
            )
          : FilledButton(
              statesController: _states,
              onPressed: _busy || widget.onPressed == null ? null : press,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 14,
                ),
                shape: shape,
              ),
              child: child,
            ),
    ),
    );
  }
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

class PageBody extends StatelessWidget {
  const PageBody({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: children,
        ),
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: EchoTheme.gold,
      fontSize: 11,
      letterSpacing: 3,
      fontWeight: FontWeight.w600,
    ),
  );
}

class Stat extends StatelessWidget {
  const Stat(this.value, this.label, {super.key});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: EchoTheme.cream,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.3,
            color: EchoTheme.muted,
          ),
        ),
      ],
    ),
  );
}

class Panel extends StatelessWidget {
  const Panel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: EchoTheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xff2c3b39)),
    ),
    child: child,
  );
}

class Stars extends StatelessWidget {
  const Stars(this.count, {this.size = 25, super.key});
  final int count;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count of 3 stars',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < count ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i < count ? EchoTheme.gold : const Color(0xff64716a),
        ),
      ),
    ),
  );
}

class RoomPreview extends StatelessWidget {
  const RoomPreview(this.room, {super.key});
  final Room room;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: AspectRatio(
      aspectRatio: 400 / 440,
      child: CustomPaint(painter: _RoomPainter(room)),
    ),
  );
}

class _RoomPainter extends CustomPainter {
  _RoomPainter(this.room);
  final Room room;
  final RoomArt art = RoomArt();
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 400, size.height / 440);
    art.background(c);
    for (final o in room.objects) {
      art.object(c, o);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) => oldDelegate.room != room;
}

class ObjectArtwork extends StatelessWidget {
  const ObjectArtwork({required this.art, this.locked = false, super.key});
  final String art;
  final bool locked;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 64,
    height: 64,
    child: ColorFiltered(
      colorFilter: ColorFilter.mode(
        locked ? const Color(0xff465552) : Colors.transparent,
        locked ? BlendMode.srcIn : BlendMode.dst,
      ),
      child: CustomPaint(painter: _ObjectPainter(art)),
    ),
  );
}

class _ObjectPainter extends CustomPainter {
  _ObjectPainter(this.art);
  final String art;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 100, s.height / 100);
    RoomArt().drawObject(
      c,
      RoomObject(
        id: 'display',
        art: art,
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        color: 0xffa5634e,
        text: '21',
      ),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_ObjectPainter oldDelegate) => oldDelegate.art != art;
}

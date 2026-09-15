import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../widgets/common.dart';

/// Presentation only: no game session, lives, daily state or rewards are touched.
class HowToPlayScreen extends ConsumerStatefulWidget {
  const HowToPlayScreen({this.firstLaunch = false, this.onFinished, super.key});
  final bool firstLaunch;
  final VoidCallback? onFinished;
  @override
  ConsumerState<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends ConsumerState<HowToPlayScreen> {
  static const steps = [
    (Icons.visibility_outlined, 'LOOK CLOSELY', 'Remember the room.'),
    (Icons.nightlight_outlined, 'LIGHTS OUT', 'One detail changes in the dark.'),
    (Icons.touch_app_outlined, 'FIND THE CHANGE', 'Tap what changed — even if it disappeared.'),
  ];
  int _step = 0;
  bool _leaving = false;
  Future<void> _finish({bool skipped = false}) async {
    if (_leaving) return;
    setState(() => _leaving = true);
    try {
      await ref.read(profileProvider.notifier).finishIntro(skipped: skipped);
      if (mounted) widget.onFinished?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _leaving = false);
        showMessage(context, 'Could not save. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !widget.firstLaunch,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || !widget.firstLaunch || _leaving) return;
      if (_step > 0) { setState(() => _step--); } else { _finish(skipped: true); }
    },
    child: Scaffold(
      appBar: AppBar(title: Text(widget.firstLaunch ? 'ECHO ROOM' : 'HOW TO PLAY')),
      body: PageBody(children: [
        const SizedBox(height: 24),
        if (widget.firstLaunch) ...[
          Eyebrow('STEP ${_step + 1} OF 3'),
          const SizedBox(height: 24),
          ExcludeSemantics(child: Icon(steps[_step].$1, size: 48)),
          const SizedBox(height: 20),
          Semantics(header: true, liveRegion: true, child: Text(steps[_step].$2,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium)),
          const SizedBox(height: 12),
          Text(steps[_step].$3, textAlign: TextAlign.center),
          const SizedBox(height: 32),
          ActionButton(_step == 2 ? 'LET’S PLAY' : 'CONTINUE', onPressed: _leaving ? null : () async {
            if (_step == 2) { await _finish(); } else { setState(() => _step++); }
          }),
          const SizedBox(height: 12),
          ActionButton('SKIP', secondary: true, onPressed: _leaving ? null : () => _finish(skipped: true)),
        ] else ...[
          for (final step in steps) ListTile(
            leading: Icon(step.$1), title: Text(step.$2), subtitle: Text(step.$3)),
          const ListTile(leading: Icon(Icons.lightbulb_outline), title: Text('HINTS'),
              subtitle: Text('Narrow the search, pulse nearby, then reveal. Hints reduce your score.')),
          const ListTile(leading: Icon(Icons.star_outline), title: Text('STARS & PROGRESS'),
              subtitle: Text('Faster solves with fewer mistakes and hints earn more stars. Solve to unlock the next room; replay to improve your best.')),
          const ListTile(leading: Icon(Icons.calendar_today_outlined), title: Text('DAILY ROOM'),
              subtitle: Text('One official result each local day. Separate from Chapter progress, with three free hints.')),
          const ListTile(leading: Icon(Icons.save_outlined), title: Text('YOUR GAME'),
              subtitle: Text('Progress is saved on this device. Control Music, Sound effects and Haptics in Settings.')),
        ],
        const SizedBox(height: 24),
      ]),
    ),
  );
}

class FirstRunGate extends ConsumerStatefulWidget {
  const FirstRunGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends ConsumerState<FirstRunGate> {
  late bool _required;
  @override
  void initState() {
    super.initState();
    _required = ref.read(profileProvider).settings.introVersion < 1;
  }
  @override
  Widget build(BuildContext context) => _required
      ? HowToPlayScreen(firstLaunch: true,
          onFinished: () => setState(() => _required = false))
      : widget.child;
}

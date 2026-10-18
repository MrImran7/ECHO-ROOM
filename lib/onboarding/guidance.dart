import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';

/// A contextual cue is claimed once when it is actually presented, never per tick.
/// It stays visible for this widget's lifetime, even after the preference is saved.
class Guidance extends ConsumerStatefulWidget {
  const Guidance({required this.id, required this.text, this.fallback = const SizedBox.shrink(), this.eligible = true, super.key});
  final String id, text;
  final bool eligible;
  final Widget fallback;
  @override
  ConsumerState<Guidance> createState() => _GuidanceState();
}

class _GuidanceState extends ConsumerState<Guidance> {
  late final bool _show;
  @override
  void initState() {
    super.initState();
    _show = widget.eligible && !ref.read(profileProvider).settings.seenTips.contains(widget.id);
    if (_show) WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(profileProvider.notifier).markTip(widget.id);
      } catch (_) {
        // ProfileController retains the save error and offers its existing retry.
        // A failed optional tip write must not interrupt an answer timer.
      }
    });
  }

  @override
  Widget build(BuildContext context) => _show
      ? Semantics(liveRegion: true, child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(widget.text, textAlign: TextAlign.center)))
      : widget.fallback;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../game/session_controller.dart';
import 'gameplay_screen.dart';
Future<void> launchGame(BuildContext context, WidgetRef ref, int level, {bool daily = false, bool resume = false}) async {
  final controller = ref.read(sessionProvider.notifier);
  if (resume) { controller.restore(); } else { await controller.start(level, daily: daily); }
  if (context.mounted) await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GameplayScreen()));
}

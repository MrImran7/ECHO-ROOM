import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/config.dart';
import '../models/progress.dart';
import '../widgets/common.dart';
import 'daily_service.dart';

/// Daily-only hierarchy; no chapter stars, rewards or streak multipliers.
class DailyResultBody extends StatelessWidget {
  const DailyResultBody({required this.date, required this.record,
    required this.progress, required this.onHome, super.key});
  final String date;
  final DailyRecord record;
  final Progress progress;
  final Future<void> Function()? onHome;

  @override
  Widget build(BuildContext context) {
    final won = record.state == DailyAttemptState.completed;
    final previous = progress.daily.entries.where((entry) =>
        entry.key.compareTo(date) < 0 && entry.value.state == DailyAttemptState.completed);
    final first = won && previous.isEmpty;
    final best = won && previous.isNotEmpty && previous.every((entry) =>
        record.responseTimeMs < entry.value.responseTimeMs);
    return PageBody(children: [
      const SizedBox(height: 16),
      Icon(won ? Icons.check_circle_outline : Icons.close_rounded, color: EchoTheme.gold, size: 42),
      const SizedBox(height: 12),
      Text(won ? 'DAILY ROOM COMPLETE' : 'DAILY ROOM MISSED',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(MaterialLocalizations.of(context).formatFullDate(DateTime.parse(date)), textAlign: TextAlign.center),
      if (!won && progress.daily[previousDate(date)]?.status == 'won')
        const Padding(padding: EdgeInsets.only(top: 12),
            child: Text('STREAK ENDED · A new start tomorrow.', textAlign: TextAlign.center)),
      if (won) ...[
        const SizedBox(height: 20),
        const Eyebrow('RESPONSE TIME'),
        Text('${(record.responseTimeMs / 1000).toStringAsFixed(2)}s',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineLarge),
        if (first || best) Padding(padding: const EdgeInsets.only(top: 8),
            child: Eyebrow(first ? 'YOUR FIRST DAILY FIND' : 'NEW DAILY BEST')),
      ],
      const SizedBox(height: 20),
      Panel(child: Column(children: [
        if (won) TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: record.score.toDouble()),
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero
              : const Duration(milliseconds: GameConfig.scoreAnimationMilliseconds),
          builder: (_, score, _) => Text('${score.round()} POINTS', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        Text('DAILY STREAK: ${progress.dailyStreak}', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('BEST DAILY STREAK: ${progress.bestDailyStreak}', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('${record.hintsUsed} / 3 DAILY HINTS USED', textAlign: TextAlign.center),
      ])),
      const SizedBox(height: 20),
      ActionButton('HOME', onPressed: onHome),
      const SizedBox(height: 12),
      const Text('A new room awaits at local midnight.', textAlign: TextAlign.center),
    ]);
  }
}

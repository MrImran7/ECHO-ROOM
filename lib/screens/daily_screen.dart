import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../daily/daily_service.dart';
import '../widgets/common.dart';
import 'launch_game.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({super.key});
  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}
class _DailyScreenState extends ConsumerState<DailyScreen> {
  Timer? _clock;
  @override
  void initState() { super.initState(); _clock = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _clock?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now(), p = ref.watch(profileProvider);
    final today = dateKey(now), count = ref.watch(catalogProvider).requireValue.levels.length;
    final record = p.daily[today];
    final resume = p.activeSession?['dailyDate'] == today;
    return Scaffold(appBar: AppBar(title: const Text('DAILY ROOM')), body: PageBody(children: [
      const SizedBox(height: 32), const Icon(Icons.nightlight_outlined, color: EchoTheme.gold, size: 62),
      const SizedBox(height: 24), Eyebrow(today), const SizedBox(height: 16),
      Text('One room.\nOne chance.', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
      const SizedBox(height: 16), const Text('A fresh detail, every day.\nNo hints. One attempt. Trust your memory.', textAlign: TextAlign.center),
      const SizedBox(height: 30), Panel(child: Row(children: [Stat('${visibleDailyStreak(p, now)}', 'DAILY STREAK'), Stat('${p.bestDailyStreak}', 'BEST STREAK')])),
      const SizedBox(height: 28),
      if (record == null || resume) ActionButton(resume ? 'CONTINUE DAILY' : 'ENTER DAILY ROOM', onPressed: () => launchGame(
        context, ref, const LocalDailyChallengeSource().levelFor(DateTime.now(), count), daily: true, resume: resume))
      else Panel(child: Column(children: [Icon(record.status == 'won' ? Icons.check_circle_outline : Icons.nightlight_outlined, color: EchoTheme.gold),
        const SizedBox(height: 12), Text(record.status == 'won' ? 'REMEMBERED' : 'THE SECRET STAYS'),
        Text('${record.time.toStringAsFixed(2)}s · ${record.score} points'), const SizedBox(height: 8), const Text('A new room awaits tomorrow.'),
      ])),
      const SizedBox(height: 30), const Eyebrow('RECENT ROOMS'), const SizedBox(height: 12),
      for (final key in (p.daily.keys.toList()..sort((a, b) => b.compareTo(a))).take(7)) ListTile(
        contentPadding: EdgeInsets.zero, leading: Icon(p.daily[key]!.status == 'won' ? Icons.check : Icons.remove,
          color: EchoTheme.gold), title: Text(key), trailing: Text(p.daily[key]!.status == 'started' ? 'PAUSED' : '${p.daily[key]!.time.toStringAsFixed(2)}s')),
    ]));
  }
}

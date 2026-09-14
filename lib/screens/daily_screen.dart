import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/config.dart';
import '../daily/daily_service.dart';
import '../daily/debug_daily_lab.dart';
import '../widgets/common.dart';
import '../models/progress.dart';
import 'launch_game.dart';

class DailyScreen extends ConsumerStatefulWidget {
  const DailyScreen({this.onExitLab, super.key});
  final VoidCallback? onExitLab;
  @override
  ConsumerState<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends ConsumerState<DailyScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(analyticsProvider).log('daily_room_opened');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _opening = false;
  String? _entryError;

  Future<void> _play() async {
    if (_opening) return;
    _opening = true;
    _entryError = null;
    try {
    // Read again at touch time: an entry screen may have crossed midnight.
    final p = ref.read(profileProvider);
    final now = ref.read(clockProvider).now();
    final today = dateKey(now);
    final saved = p.activeSession;
    if (saved == null && (p.daily[today]?.finalized ?? false)) {
      setState(() {});
      return;
    }
    await launchGame(context, ref, 1, daily: true, resume: saved != null);
    if (mounted) setState(() {});
    } on StateError catch (error) {
      if (mounted) setState(() => _entryError = error.message);
    } on FormatException catch (error) {
      if (GameConfig.debugTools) debugPrint('Daily configuration: $error');
      if (mounted) setState(() => _entryError = 'The daily puzzle could not be loaded. Your attempt is unchanged.');
    } finally { _opening = false; }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(savedProgressProvider);
    final catalog = ref.watch(catalogProvider);
    if (loaded.hasError || catalog.hasError) {
      return Scaffold(appBar: AppBar(title: const Text('DAILY ROOM')),
        body: PageBody(children: [
          const Text('DAILY ROOM UNAVAILABLE', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ActionButton('TRY AGAIN', onPressed: () async {
            if (loaded.hasError) ref.invalidate(savedProgressProvider);
            if (catalog.hasError) ref.invalidate(catalogProvider);
          }),
        ]));
    }
    if (!loaded.hasValue || !catalog.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(semanticsLabel: 'Loading Daily Room')));
    }
    final now = ref.read(clockProvider).now(), p = ref.watch(profileProvider);
    final today = dateKey(now);
    final record = p.daily[today];
    final saved = p.activeSession;
    final savedDate = saved?['dailyDate'] as String?;
    final finalized = record?.finalized ?? false;
    final owningDate = savedDate == null ? now : DateTime.parse(savedDate);
    final formattedDate = MaterialLocalizations.of(context).formatFullDate(owningDate);
    final state = savedDate != null ? DailyAttemptState.interrupted : dailyAttemptState(p, now);
    final (statusLabel, statusIcon) = switch (state) {
      DailyAttemptState.available => ('NEW · ONE CHANCE', Icons.fiber_new_outlined),
      DailyAttemptState.started || DailyAttemptState.interrupted => ('RESUME · EXISTING ATTEMPT', Icons.restore),
      DailyAttemptState.completed => ('COMPLETE', Icons.check_circle_outline),
      DailyAttemptState.failed => ('MISSED', Icons.close_rounded),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('DAILY ROOM')),
      body: PageBody(
        children: [
          const SizedBox(height: 32),
          Icon(statusIcon, color: EchoTheme.gold, size: 48),
          const SizedBox(height: 12),
          Text(statusLabel, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(formattedDate, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            finalized ? 'Today is written.' : 'One room.\nOne chance.',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'One official attempt. Three free hint strengths.\nHints reduce your score. Chapter lives stay untouched.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          Panel(child: Row(children: [
            Stat('${visibleDailyStreak(p, now)}', 'DAILY STREAK'),
            Stat('${p.bestDailyStreak}', 'BEST DAILY STREAK'),
          ])),
          const SizedBox(height: 10),
          const Text('Complete Daily Room on consecutive days.', textAlign: TextAlign.center),
          const SizedBox(height: 28),
          if (finalized)
            Panel(child: Column(children: [
              Icon(record!.status == 'won' ? Icons.check_circle_outline : Icons.nightlight_outlined,
                  color: EchoTheme.gold),
              const SizedBox(height: 12),
              Text(record.status == 'won' ? 'TODAY COMPLETE' : 'DAILY ROOM MISSED'),
              Text(record.status == 'won'
                  ? 'Solved in ${(record.responseTimeMs / 1000).toStringAsFixed(2)}s'
                  : 'The room kept its secret.'),
              Text('${record.score} points · ${record.hintsUsed} hints'),
              const SizedBox(height: 8),
              const Text('A new room awaits at local midnight.', textAlign: TextAlign.center),
            ])),
          if (_entryError != null) ...[
            const Text('DAILY ROOM UNAVAILABLE', textAlign: TextAlign.center),
            Text(_entryError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
          ],
          if (saved != null) ...[
            const SizedBox(height: 12),
            Text(savedDate == null
                ? 'Your chapter room is paused. Finish it before starting daily play.'
                : 'Resume ${MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(savedDate))}. The result belongs to that date, even after midnight.',
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ActionButton(savedDate == null ? 'CONTINUE CHAPTER ROOM' : 'RESUME DAILY ROOM', onPressed: _play),
          ] else if (!finalized)
            ActionButton(record == null ? 'PLAY DAILY ROOM' : 'RESUME DAILY ROOM', onPressed: _play),
          const SizedBox(height: 30),
          const Eyebrow('RECENT ROOMS'),
          const SizedBox(height: 12),
          if (p.daily.isEmpty)
            const Text('Your first daily memory starts here.', textAlign: TextAlign.center),
          for (final key in (p.daily.keys.toList()..sort((a, b) => b.compareTo(a))).take(7))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(p.daily[key]!.status == 'won' ? Icons.check : p.daily[key]!.status == 'lost' ? Icons.close : Icons.pause, color: EchoTheme.gold),
              title: Text(MaterialLocalizations.of(context).formatMediumDate(DateTime.parse(key))),
              subtitle: Text(switch (p.daily[key]!.status) {
                'won' => 'SOLVED · ${p.daily[key]!.time.toStringAsFixed(2)}s',
                'lost' => 'MISSED',
                _ => 'UNFINISHED',
              }),
            ),
          if (GameConfig.debugTools) ...[
            if (widget.onExitLab != null)
              DailyLabControls(onRefresh: () { if (mounted) setState(() {}); }, onExit: widget.onExitLab!)
            else
              TextButton(onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => DailyDebugLab(baseClock: ref.read(clockProvider)))),
                child: const Text('OPEN DAILY LAB')),
            const SizedBox(height: 16),
            Text('DEBUG · $today · pool v${LocalDailyChallengeSource.dailyPoolVersion} · puzzle ${record?.levelId ?? const LocalDailyChallengeSource().levelFor(now, ref.read(catalogProvider).requireValue.levels.length)}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

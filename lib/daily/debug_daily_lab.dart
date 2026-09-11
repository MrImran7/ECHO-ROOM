import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/config.dart';
import '../game/session_controller.dart';
import '../models/progress.dart';
import '../screens/daily_screen.dart';
import '../storage/progress_repository.dart';
import 'daily_service.dart';

/// A nested provider scope keeps all simulated saves in RAM. The real profile,
/// repository, active attempt and system clock are never overridden globally.
class DailyDebugLab extends StatefulWidget {
  const DailyDebugLab({required this.baseClock, super.key});
  final LocalClock baseClock;
  @override
  State<DailyDebugLab> createState() => _DailyDebugLabState();
}

class _DailyDebugLabState extends State<DailyDebugLab> {
  final _repository = MemoryProgressRepository();
  late final _clock = DebugDailyClock(widget.baseClock);
  @override
  Widget build(BuildContext context) {
    if (!GameConfig.debugTools) return const SizedBox.shrink();
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_repository),
        savedProgressProvider.overrideWith((ref) async => _repository.load()),
        profileProvider.overrideWith(ProfileController.new),
        sessionProvider.overrideWith(SessionController.new),
        clockProvider.overrideWithValue(_clock),
      ],
      child: Consumer(builder: (context, ref, _) {
        final saved = ref.watch(savedProgressProvider);
        return saved.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => const Center(child: Text('Daily Lab could not open.')),
          data: (_) => MaterialApp(
            theme: EchoTheme.theme,
            home: DailyScreen(onExitLab: () => Navigator.of(this.context).pop()),
          ),
        );
      }),
    );
  }
}

class DebugDailyClock implements LocalClock {
  DebugDailyClock(this.base);
  final LocalClock base;
  DateTime? _override;
  bool get overridden => GameConfig.debugTools && _override != null;
  void setDate(DateTime? value) {
    if (GameConfig.debugTools) _override = value;
  }
  @override
  DateTime now() => GameConfig.debugTools && _override != null
      ? _override!
      : base.now();
}

class DailyLabControls extends ConsumerWidget {
  const DailyLabControls({required this.onRefresh, required this.onExit, super.key});
  final VoidCallback onRefresh, onExit;

  Future<void> _simulate(WidgetRef ref, String? status) async {
    if (!GameConfig.debugTools) return;
    final p = ref.read(profileProvider);
    if (p.activeSession != null) throw StateError('Clear the interrupted attempt first.');
    final date = previousDate(dateKey(ref.read(clockProvider).now()));
    final daily = p.daily.map((key, value) => MapEntry(key, value.toJson()));
    if (status == null) {
      daily.remove(date);
    } else {
      daily[date] = DailyRecord(levelId: const LocalDailyChallengeSource()
          .levelFor(DateTime.parse(date), ref.read(catalogProvider).requireValue.levels.length),
          status: status, time: status == 'won' ? 2 : 0).toJson();
    }
    await ref.read(profileProvider.notifier).commit(p.patch({
      'daily': daily, 'dailyStreak': status == 'won' ? 1 : 0,
      'bestDailyStreak': status == 'won' && p.bestDailyStreak < 1 ? 1 : p.bestDailyStreak,
      'lastDailyWin': status == 'won' ? date : null,
    }));
    onRefresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!GameConfig.debugTools) return const SizedBox.shrink();
    final clock = ref.read(clockProvider) as DebugDailyClock;
    return Column(children: [
      const Text('DAILY LAB · MEMORY ONLY', style: TextStyle(color: EchoTheme.gold)),
      const Text('Simulated results disappear when you exit. Real progress is untouched.', textAlign: TextAlign.center),
      Wrap(alignment: WrapAlignment.center, children: [
        TextButton(onPressed: () async {
          final date = await showDatePicker(context: context, initialDate: clock.now(),
              firstDate: DateTime(2020), lastDate: DateTime(2100));
          if (date != null) { clock.setDate(date); onRefresh(); }
        }, child: const Text('OVERRIDE DATE')),
        TextButton(onPressed: () { clock.setDate(null); onRefresh(); }, child: const Text('REAL DATE')),
        TextButton(onPressed: () async {
          final p = ref.read(profileProvider);
          final today = dateKey(clock.now());
          final records = p.daily.map((key, value) => MapEntry(key, value.toJson()))..remove(today);
          await ref.read(profileProvider.notifier).commit(p.patch({
            'daily': records, 'dailyStreak': 0,
            'lastDailyWin': null,
            if (p.activeSession?['dailyDate'] == today) 'activeSession': null,
          }));
          onRefresh();
        }, child: const Text('CLEAR TODAY')),
        TextButton(onPressed: () async {
          final p = ref.read(profileProvider);
          final date = p.activeSession?['dailyDate'] as String?;
          if (date != null) {
            final records = p.daily.map((key, value) => MapEntry(key, value.toJson()));
            if (!(p.daily[date]?.finalized ?? false)) records.remove(date);
            await ref.read(profileProvider.notifier).commit(p.patch({'activeSession': null, 'daily': records}));
            onRefresh();
          }
        }, child: const Text('CLEAR INTERRUPTED')),
        for (final option in {'YESTERDAY SOLVED': 'won', 'YESTERDAY FAILED': 'lost', 'MISSED DAY': null}.entries)
          TextButton(onPressed: ref.watch(profileProvider).activeSession != null
              ? null : () => _simulate(ref, option.value), child: Text(option.key)),
        TextButton(onPressed: onExit, child: const Text('EXIT LAB')),
      ]),
    ]);
  }
}

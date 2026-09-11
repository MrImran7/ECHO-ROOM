import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/config.dart';
import '../daily/daily_service.dart';
import '../services/lives_service.dart';
import '../widgets/common.dart';
import 'chapters_screen.dart';
import 'collection_screen.dart';
import 'daily_screen.dart';
import 'launch_game.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _lifeTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = ref.read(profileProvider);
      ref.read(audioProvider).configure(p.settings);
      ref.read(hapticsProvider).enabled = p.settings.haptics;
      ref.read(analyticsProvider).log('app_open');
    });
  }

  void _refresh() {
    unawaited(
      ref
          .read(profileProvider.notifier)
          .refreshLives()
          .catchError((Object _) {}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      if (mounted) setState(() {});
      ref.read(audioProvider).resume();
      ref.read(hapticsProvider).resume();
    } else {
      ref.read(audioProvider).suspend();
      ref.read(hapticsProvider).suspend();
    }
  }

  @override
  void dispose() {
    _lifeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _page(Widget screen) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider),
        catalog = ref.watch(catalogProvider).requireValue;
    final regeneration = const LivesService().untilNext(p, DateTime.now());
    return Scaffold(
      body: PageBody(
        children: [
          const SizedBox(height: 20),
          const Eyebrow('A GAME OF SECOND GLANCES'),
          const SizedBox(height: 22),
          Text(
            'ECHO\nROOM',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 14),
          const Text(
            'Trust your eyes. Question your memory.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          Stack(
            children: [
              RoomPreview(catalog.rooms.values.first),
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xdd172424),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '01 / THE APARTMENT',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Color(0xffead7b0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Stat(p.highestLevel.toString().padLeft(2, '0'), 'CURRENT ROOM'),
              Stat(
                GameConfig.livesEnabled
                    ? '${p.lives} / ${GameConfig.maxLives}'
                    : '∞',
                'LIVES',
              ),
              Stat('${p.streak}', 'STREAK'),
            ],
          ),
          if (GameConfig.livesEnabled && regeneration != null) ...[
            const SizedBox(height: 12),
            Text(
              'Next life in ${regeneration.inMinutes}:${(regeneration.inSeconds % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Eyebrow(
            '${p.totalStars(catalog.levels.length)} / ${catalog.levels.length * 3} ★ · THE APARTMENT',
          ),
          const SizedBox(height: 25),
          ActionButton(
            p.activeSession != null ? 'CONTINUE ROOM' : 'PLAY',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => launchGame(
              context,
              ref,
              p.highestLevel,
              resume: p.activeSession != null,
            ),
          ),
          const SizedBox(height: 12),
          ActionButton(
            'DAILY ROOM · ${dailyStatus(p, ref.read(clockProvider).now())}',
            icon: Icons.nightlight_outlined,
            secondary: true,
            onPressed: () => _page(const DailyScreen()),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _page(const ChaptersScreen()),
                child: const Text('CHAPTERS'),
              ),
              TextButton(
                onPressed: () => _page(const CollectionScreen()),
                child: const Text('COLLECTION'),
              ),
              TextButton(
                onPressed: () => _page(const SettingsScreen()),
                child: const Text('SETTINGS'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'One room. One change. A little doubt.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xff9baaa6)),
          ),
        ],
      ),
    );
  }
}

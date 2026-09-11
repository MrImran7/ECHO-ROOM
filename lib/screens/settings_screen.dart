import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/config.dart';
import '../services/audio_service.dart';
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider),
        controller = ref.read(profileProvider.notifier);
    Future<void> change(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted)
          showMessage(context, 'Could not save. Please try again.');
      }
    }

    final debug = ref.watch(debugProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: PageBody(
        children: [
          const SizedBox(height: 20),
          const Eyebrow('MAKE YOURSELF AT HOME'),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Music'),
            subtitle: const Text('A little atmosphere'),
            value: p.settings.music,
            onChanged: (v) => change(
              () => controller.settings(
                ref.read(profileProvider).settings.copyWith(music: v),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Sound effects'),
            value: p.settings.sound,
            onChanged: (v) => change(
              () => controller.settings(
                ref.read(profileProvider).settings.copyWith(sound: v),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text('Feel the find'),
            value: p.settings.haptics,
            onChanged: (v) => change(
              () => controller.settings(
                ref.read(profileProvider).settings.copyWith(haptics: v),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          ActionButton(
            'RESET PROGRESS',
            secondary: true,
            onPressed: () async {
              final reset = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Start over?'),
                  content: const Text(
                    'This removes room progress, daily history, achievements and collectibles. Your sound settings are kept.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('RESET'),
                    ),
                  ],
                ),
              );
              if (reset == true) {
                await controller.reset();
                if (context.mounted) showMessage(context, 'A fresh start.');
              }
            },
          ),
          const SizedBox(height: 30),
          const Text(
            'Your room stays yours.\nOffline. No accounts. No tracking.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'ECHO ROOM · 0.1.0',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: EchoTheme.gold,
              letterSpacing: 2,
            ),
          ),
          if (GameConfig.debugTools) ...[
            const SizedBox(height: 35),
            const Divider(),
            const Eyebrow('DEVELOPMENT'),
            const Text('Haptic API test · respects Haptics and Android system settings'),
            Wrap(spacing: 8, children: [
              for (final probe in HapticProbe.values)
                TextButton(
                  onPressed: () => ref.read(hapticsProvider).debugProbe(probe),
                  child: Text('TEST ${probe.name.toUpperCase()}'),
                ),
            ]),
            SwitchListTile(
              title: const Text('Unlock all levels'),
              value: debug.unlockAll,
              onChanged: (v) =>
                  ref.read(debugProvider.notifier).update(unlockAll: v),
            ),
            SwitchListTile(
              title: const Text('Skip countdown'),
              value: debug.skipCountdown,
              onChanged: (v) =>
                  ref.read(debugProvider.notifier).update(skipCountdown: v),
            ),
            SwitchListTile(
              title: const Text('Skip observation'),
              value: debug.skipObservation,
              onChanged: (v) =>
                  ref.read(debugProvider.notifier).update(skipObservation: v),
            ),
            SwitchListTile(
              title: const Text('Show hit regions & frame stats'),
              value: debug.hitboxes,
              onChanged: (v) =>
                  ref.read(debugProvider.notifier).update(hitboxes: v),
            ),
            const Text(
              'Select any unlocked room from Chapters.\nLives enabled: ${GameConfig.livesEnabled}\nRegeneration: ${GameConfig.lifeMinutes} minutes',
              style: const TextStyle(fontSize: 12),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => change(
                    () => controller.commit(p.patch({'hints': p.hints + 10})),
                  ),
                  child: const Text('+10 HINTS'),
                ),
                TextButton(
                  onPressed: () => change(
                    () => controller.commit(
                      p.patch({'hints': (p.hints - 1).clamp(0, 999)}),
                    ),
                  ),
                  child: const Text('−1 HINT'),
                ),
                TextButton(
                  onPressed: () => change(
                    () => controller.commit(
                      p.patch({
                        'lives': GameConfig.maxLives,
                        'lifeAnchor': null,
                      }),
                    ),
                  ),
                  child: const Text('RESET LIVES'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

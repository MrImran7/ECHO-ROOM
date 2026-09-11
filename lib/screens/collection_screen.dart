import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../achievements/definitions.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../collection/definitions.dart';
import '../widgets/common.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('COLLECTION')),
      body: PageBody(
        children: [
          const Eyebrow('THINGS LEFT BEHIND'),
          const SizedBox(height: 16),
          Text(
            'Familiar strangers.',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '${p.collectibles.length} / ${collectibles.length} mystery objects',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          for (final item in collectibles) ...[
            Panel(
              child: Row(
                children: [
                  ObjectArtwork(
                    art: item.art,
                    locked: !p.collectibles.contains(item.id),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.collectibles.contains(item.id)
                              ? item.name
                              : 'Unknown object',
                          style: const TextStyle(
                            color: EchoTheme.cream,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.collectibles.contains(item.id)
                              ? item.description
                              : item.condition,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          Eyebrow('ACHIEVEMENTS · ${p.achievements.length} / ${achievements.length}'),
          const SizedBox(height: 12),
          Panel(child: Column(children: [
            const Eyebrow('YOUR OBSERVATION RECORD'),
            const SizedBox(height: 12),
            Text('${p.correctAnswers} solves · ${p.wrongTaps} wrong taps · ${p.hintsUsed} hints used', textAlign: TextAlign.center),
            Text('Best streak ${p.bestStreak} · Best time ${p.bestResponseTime == null ? '—' : '${p.bestResponseTime!.toStringAsFixed(2)}s'}', textAlign: TextAlign.center),
          ])),
          for (final a in achievements)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5),
              leading: Icon(
                p.achievements.contains(a.id)
                    ? Icons.workspace_premium
                    : Icons.lock_outline,
                color: p.achievements.contains(a.id)
                    ? EchoTheme.gold
                    : EchoTheme.muted,
              ),
              title: Text(
                a.name,
                style: const TextStyle(fontSize: 13, letterSpacing: 1),
              ),
              subtitle: Text(
                '${a.description}\n${p.achievements.contains(a.id) ? 'UNLOCKED' : a.progressLabel(p, ref.read(catalogProvider).requireValue.levels.length)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

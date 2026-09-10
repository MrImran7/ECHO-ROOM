import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/config.dart';
import '../widgets/common.dart';
import 'launch_game.dart';

class ChaptersScreen extends ConsumerWidget {
  const ChaptersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider),
        catalog = ref.watch(catalogProvider).requireValue;
    final unlockAll =
        GameConfig.debugTools && ref.watch(debugProvider).unlockAll;
    return Scaffold(
      appBar: AppBar(title: const Text('CHAPTERS')),
      body: PageBody(
        children: [
          const Eyebrow('CHAPTER 01'),
          const SizedBox(height: 12),
          Text(
            'The Apartment',
            style: Theme.of(context).textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            '${p.levels.length} / ${catalog.levels.length} rooms remembered',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          RoomPreview(catalog.rooms.values.first),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, bounds) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: bounds.maxWidth < 330 ? 3 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .9,
              ),
              itemCount: catalog.levels.length,
              itemBuilder: (context, index) {
                final id = catalog.levels[index].levelId,
                    locked = id > p.highestLevel && !unlockAll;
                return Semantics(
                  label: 'Room $id${locked ? ', locked' : ''}',
                  child: Material(
                    color: EchoTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: locked
                          ? null
                          : () async {
                              try {
                                await launchGame(context, ref, id);
                              } catch (e) {
                                if (context.mounted)
                                  showMessage(
                                    context,
                                    e.toString().replaceFirst(
                                      'Bad state: ',
                                      '',
                                    ),
                                  );
                              }
                            },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (locked)
                            const Icon(
                              Icons.lock_outline,
                              size: 20,
                              color: EchoTheme.muted,
                            )
                          else
                            Text(
                              id.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Stars(p.levels[id]?.stars ?? 0, size: 17),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          for (final chapter in catalog.chapters.where((c) => !c.available))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline, color: EchoTheme.muted),
              title: Text(
                chapter.title,
                style: const TextStyle(fontSize: 13, letterSpacing: 1),
              ),
              subtitle: Text('Chapter ${chapter.id} · Coming later'),
            ),
        ],
      ),
    );
  }
}

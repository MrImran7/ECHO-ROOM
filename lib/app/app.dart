import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/progress.dart';
import '../screens/home_screen.dart';
import '../widgets/common.dart';
import 'providers.dart';
import 'theme.dart';

class EchoRoomApp extends StatelessWidget {
  const EchoRoomApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Echo Room',
    debugShowCheckedModeBanner: false,
    theme: EchoTheme.theme,
    home: const _Bootstrap(),
  );
}

class _Bootstrap extends ConsumerWidget {
  const _Bootstrap();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider),
        progress = ref.watch(savedProgressProvider);
    if (catalog.hasError || progress.hasError) {
      return Scaffold(
        body: PageBody(
          children: [
            const SizedBox(height: 70),
            const Eyebrow('THE DOOR IS STUCK'),
            const SizedBox(height: 20),
            Text(
              progress.hasError
                  ? 'Your saved progress could not be read. Retry first, or reset the save to start over.'
                  : 'The room could not be loaded. Please retry.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ActionButton(
              'RETRY',
              onPressed: () async {
                ref.invalidate(catalogProvider);
                ref.invalidate(savedProgressProvider);
              },
            ),
            if (progress.hasError) ...[
              const SizedBox(height: 12),
              ActionButton(
                'RESET DAMAGED SAVE',
                secondary: true,
                onPressed: () async {
                  final reset = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remove saved progress?'),
                      content: const Text(
                        'This permanently replaces the unreadable save with a fresh game.',
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
                    await ref.read(repositoryProvider).save(Progress());
                    ref.invalidate(savedProgressProvider);
                  }
                },
              ),
            ],
          ],
        ),
      );
    }
    if (!catalog.hasValue || !progress.hasValue)
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow('ECHO ROOM'),
              SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ],
          ),
        ),
      );
    return const HomeScreen();
  }
}

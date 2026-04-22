import 'package:annoto/app/themes.dart';
import 'package:flutter/material.dart';

const _hashOptions = [16, 32, 64, 128, 256];

class EngineSettingsScreen extends StatelessWidget {
  const EngineSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        engineThreadsNotifier,
        engineHashNotifier,
        engineNameNotifier,
      ]),
      builder: (context, child) {
        final theme = Theme.of(context);
        final engineName = engineNameNotifier.value;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton.filled(
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor:
                    theme.inputDecorationTheme.fillColor ??
                    theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              tooltip: 'Back',
              icon: const Icon(Icons.chevron_left, size: 22),
            ),
            title: const Text('Engine settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (engineName != null) ...[
                Center(
                  child: Chip(
                    avatar: const Icon(Icons.memory, size: 16),
                    label: Text(
                      engineName,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Threads', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${engineThreadsNotifier.value}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Slider(
                        min: 1,
                        max: 8,
                        divisions: 7,
                        value: engineThreadsNotifier.value.toDouble(),
                        label: '${engineThreadsNotifier.value}',
                        onChanged: (value) {
                          engineThreadsNotifier.value = value.round();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hash', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Center(
                        child: SegmentedButton<int>(
                          segments: _hashOptions
                              .map(
                                (mb) => ButtonSegment<int>(
                                  value: mb,
                                  label: Text('${mb}MB'),
                                ),
                              )
                              .toList(),
                          selected: {engineHashNotifier.value},
                          onSelectionChanged: (selection) {
                            engineHashNotifier.value = selection.first;
                          },
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(
                            textStyle: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

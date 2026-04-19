import 'package:annoto/app/app_state.dart';
import 'package:annoto/app/ai_models.dart';
import 'package:flutter/material.dart';

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  static const routeName = '/provider';

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 22),
        ),
        title: const Text('AI provider'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provider', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  RadioGroup<AiProvider>(
                    groupValue: appState.selectedProvider,
                    onChanged: (value) {
                      if (value != null) {
                        appState.selectProvider(value);
                      }
                    },
                    child: Column(
                      children: AiProvider.values
                          .map(
                            (provider) => RadioListTile<AiProvider>(
                              value: provider,
                              contentPadding: EdgeInsets.zero,
                              title: Text(provider.label),
                            ),
                          )
                          .toList(),
                    ),
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
                  Text('Models', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        (providerModels[appState.selectedProvider] ??
                                const <String>[])
                            .map(
                              (model) => Chip(
                                label: Text(
                                  model,
                                  style: theme.textTheme.bodySmall,
                                ),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:annoto/app/app_state.dart';
import 'package:annoto/app/ai_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ProviderScreen extends StatefulWidget {
  const ProviderScreen({super.key});

  static const routeName = '/provider';

  @override
  State<ProviderScreen> createState() => _ProviderScreenState();
}

class _ProviderScreenState extends State<ProviderScreen> {
  late final Future<Map<String, AiModelPricing>> _openRouterPricing;

  @override
  void initState() {
    super.initState();
    _openRouterPricing = _fetchOpenRouterPricing();
  }

  Future<Map<String, AiModelPricing>> _fetchOpenRouterPricing() async {
    final models = providerModels[AiProvider.openrouter] ?? const <String>[];
    final response = await Dio().get<Map<String, dynamic>>(
      'https://openrouter.ai/api/v1/models',
    );
    final data = response.data?['data'];
    if (data is! List) return const {};

    final pricing = <String, AiModelPricing>{};
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      final id = item['id'];
      if (id is! String || !models.contains(id)) continue;
      final modelPricing = item['pricing'];
      if (modelPricing is! Map<String, dynamic>) continue;
      final prompt = double.tryParse(modelPricing['prompt'].toString());
      final completion = double.tryParse(modelPricing['completion'].toString());
      if (prompt == null || completion == null) continue;
      pricing[id] = AiModelPricing(
        inputPer1m: prompt * 1000000,
        outputPer1m: completion * 1000000,
      );
    }
    return pricing;
  }

  String _formatPrice(double value) {
    return value
        .toStringAsFixed(4)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _displayModelName(String model) {
    final slashIndex = model.indexOf('/');
    return slashIndex == -1 ? model : model.substring(slashIndex + 1);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final theme = Theme.of(context);
    final models =
        providerModels[appState.selectedProvider] ?? const <String>[];
    final selectedModel = selectedModelFor(appState);
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
                  FutureBuilder<Map<String, AiModelPricing>>(
                    future: _openRouterPricing,
                    builder: (context, snapshot) => Column(
                      children: models.map((model) {
                        final selected = model == selectedModel;
                        final pricing = snapshot.data?[model];
                        final color = selected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => appState.selectModel(model),
                                borderRadius: BorderRadius.circular(16),
                                child: Chip(
                                  label: Text(
                                    _displayModelName(model),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: color,
                                    ),
                                  ),
                                  backgroundColor: selected
                                      ? theme.colorScheme.primaryContainer
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.45),
                                  padding: EdgeInsets.zero,
                                  side: BorderSide(
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const Spacer(),
                              if (pricing != null)
                                Text(
                                  'in \$${_formatPrice(pricing.inputPer1m)}/M, out \$${_formatPrice(pricing.outputPer1m)}/M',
                                  textAlign: TextAlign.end,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
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

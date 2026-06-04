import 'package:annoto/app/app_state.dart';

const geminiModel = 'gemini-3.1-flash-lite';
const openRouterModel = 'openai/gpt-5.4';
const openRouterGpt55Model = 'openai/gpt-5.5';
const openRouterQwenModel = 'qwen/qwen3.7-plus';

class AiModelPricing {
  const AiModelPricing({required this.inputPer1m, required this.outputPer1m});

  final double inputPer1m;
  final double outputPer1m;
}

const providerModels = {
  AiProvider.gemini: [geminiModel],
  AiProvider.openrouter: [
    openRouterModel,
    openRouterGpt55Model,
    openRouterQwenModel,
  ],
};

String selectedModelFor(AppState appState) {
  final models = providerModels[appState.selectedProvider] ?? const <String>[];
  final selectedModel = appState.selectedModel;
  if (selectedModel != null && models.contains(selectedModel)) {
    return selectedModel;
  }
  return models.first;
}

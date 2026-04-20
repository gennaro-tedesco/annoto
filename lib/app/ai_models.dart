import 'package:annoto/app/app_state.dart';

const geminiModel = 'gemini-3.1-flash-lite-preview';
const openRouterModel = 'openai/gpt-5.4-nano';
const groqModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

const providerModels = {
  AiProvider.gemini: [geminiModel],
  AiProvider.openrouter: [openRouterModel],
  AiProvider.groq: [groqModel],
};

import 'package:annoto/app/app_state.dart';

const geminiModel = 'gemini-3.1-flash-lite-preview';
const mistralModel = 'mistral-large-latest';
const groqModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

const providerModels = {
  AiProvider.gemini: [geminiModel],
  AiProvider.mistral: [mistralModel],
  AiProvider.groq: [groqModel],
};

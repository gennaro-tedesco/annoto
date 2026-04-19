import { GoogleProvider, GroqProvider, MistralProvider, PgnProvider } from './providers.ts'

const GOOGLE_MODEL_DEFAULT = 'gemini-3.1-flash-lite-preview'
const MISTRAL_MODEL_DEFAULT = 'mistral-large-latest'
const GROQ_MODEL_DEFAULT = 'meta-llama/llama-4-scout-17b-16e-instruct'

const googleProvider: PgnProvider = new GoogleProvider({
  apiKey: Deno.env.get('GEMINI_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? GOOGLE_MODEL_DEFAULT,
})

const mistralProvider: PgnProvider = new MistralProvider({
  apiKey: Deno.env.get('MISTRAL_API_KEY')!,
  extractionModel:
    Deno.env.get('MISTRAL_EXTRACTION_MODEL') ??
    Deno.env.get('MISTRAL_MODEL') ??
    MISTRAL_MODEL_DEFAULT,
})

const groqProvider: PgnProvider = new GroqProvider({
  apiKey: Deno.env.get('GROQ_API_KEY')!,
  model: Deno.env.get('GROQ_MODEL') ?? GROQ_MODEL_DEFAULT,
})

export function getProvider(providerName?: string): PgnProvider {
  switch (providerName) {
    case 'mistral':
      return mistralProvider
    case 'groq':
      return groqProvider
    case 'google':
    default:
      return googleProvider
  }
}

import { GoogleProvider, GroqProvider, OpenRouterProvider, PgnProvider } from './providers.ts'

const GOOGLE_MODEL_DEFAULT = 'gemini-3.1-flash-lite-preview'
const OPENROUTER_MODEL_DEFAULT = 'openai/gpt-5.4-nano'
const GROQ_MODEL_DEFAULT = 'meta-llama/llama-4-scout-17b-16e-instruct'

const googleProvider: PgnProvider = new GoogleProvider({
  apiKey: Deno.env.get('GEMINI_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? GOOGLE_MODEL_DEFAULT,
})

const openRouterProvider: PgnProvider = new OpenRouterProvider({
  apiKey: Deno.env.get('OPENROUTER_API_KEY')!,
  model: Deno.env.get('OPENROUTER_MODEL') ?? OPENROUTER_MODEL_DEFAULT,
})

const groqProvider: PgnProvider = new GroqProvider({
  apiKey: Deno.env.get('GROQ_API_KEY')!,
  model: Deno.env.get('GROQ_MODEL') ?? GROQ_MODEL_DEFAULT,
})

export function getProvider(providerName?: string): PgnProvider {
  switch (providerName) {
    case 'google':
      return googleProvider
    case 'openrouter':
      return openRouterProvider
    case 'groq':
      return groqProvider
    default:
      throw new Error('unknown_provider')
  }
}

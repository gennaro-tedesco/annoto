import { GoogleProvider, GroqProvider, MistralProvider, PgnProvider } from './providers.ts'

const googleProvider: PgnProvider = new GoogleProvider({
  apiKey: Deno.env.get('GEMINI_API_KEY')!,
  model: Deno.env.get('GOOGLE_MODEL') ?? 'gemini-2.0-flash',
})

const mistralProvider: PgnProvider = new MistralProvider({
  apiKey: Deno.env.get('MISTRAL_API_KEY')!,
  model: Deno.env.get('MISTRAL_MODEL') ?? 'mistral-large-latest',
})

const groqProvider: PgnProvider = new GroqProvider({
  apiKey: Deno.env.get('GROQ_API_KEY')!,
  model: Deno.env.get('GROQ_MODEL') ?? 'meta-llama/llama-4-scout-17b-16e-instruct',
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

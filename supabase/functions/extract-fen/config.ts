import { FenProvider, GoogleProvider, GroqProvider, OpenRouterProvider } from './providers.ts'

export function getProvider(providerName: string, model: string): FenProvider {
  switch (providerName) {
    case 'google':
      return new GoogleProvider({ apiKey: Deno.env.get('GEMINI_API_KEY')!, model })
    case 'openrouter':
      return new OpenRouterProvider({ apiKey: Deno.env.get('OPENROUTER_API_KEY')!, model })
    case 'groq':
      return new GroqProvider({ apiKey: Deno.env.get('GROQ_API_KEY')!, model })
    default:
      throw new Error('unknown_provider')
  }
}

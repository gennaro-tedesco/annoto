export interface PgnProvider {
  extractPgn(imageBase64: string, mimeType: string): Promise<string>
}

const _prompt = [
  'You are a chess scoresheet transcription engine.',
  'Given the image of a handwritten or printed chess scoresheet, extract all the moves and return them as a single valid PGN string.',
  'Rules:',
  '- Use Standard Algebraic Notation (SAN) for every move.',
  '- Include move numbers (e.g. 1. e4 e5 2. Nf3 Nc6).',
  "- If a move is illegible, use '?' as a placeholder (e.g. 1. e4 ?).",
  '- Do not include any commentary, annotations, headers, or result tags.',
  '- Output ONLY the raw move-text PGN, nothing else. Example: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
].join('\n')

function _googleErrorCode(status: number, body: string): string {
  if (status === 503 && body.includes('"status": "UNAVAILABLE"')) return 'provider_unavailable'
  if (status === 404 || body.includes('not found') || body.includes('not supported')) return 'model_not_found'
  if (status === 429 || body.includes('RESOURCE_EXHAUSTED') || body.includes('quota')) return 'quota_exceeded'
  return 'extraction_failed'
}

function _mistralErrorCode(status: number, body: string): string {
  const n = body.toLowerCase()
  if (status === 503 || n.includes('unavailable')) return 'provider_unavailable'
  if (status === 404 || n.includes('not found') || n.includes('unknown model')) return 'model_not_found'
  if (status === 429 || n.includes('resource_exhausted') || n.includes('quota') || n.includes('billing') || n.includes('credit')) return 'quota_exceeded'
  return 'extraction_failed'
}

function _groqErrorCode(status: number, body: string): string {
  const n = body.toLowerCase()
  if (status === 503 || n.includes('service unavailable')) return 'provider_unavailable'
  if (status === 404 || n.includes('model not found') || n.includes('does not exist')) return 'model_not_found'
  if (status === 429 || n.includes('rate limit') || n.includes('quota')) return 'quota_exceeded'
  return 'extraction_failed'
}

export type GoogleConfig = { apiKey: string; model: string }

export class GoogleProvider implements PgnProvider {
  constructor(private readonly cfg: GoogleConfig) {}

  async extractPgn(imageBase64: string, mimeType: string): Promise<string> {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.cfg.model}:generateContent?key=${this.cfg.apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { inline_data: { mime_type: mimeType, data: imageBase64 } },
                { text: _prompt },
              ],
            },
          ],
        }),
      },
    )

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Google API error — status:', res.status, '— body:', errBody)
      const code = _googleErrorCode(res.status, errBody)
      console.error('Google API error — resolved code:', code)
      throw new Error(code)
    }

    const data = await res.json()
    const pgn: string = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? ''
    if (!pgn) throw new Error('empty_model_output')
    return pgn
  }
}

export type MistralConfig = { apiKey: string; model: string }

export class MistralProvider implements PgnProvider {
  constructor(private readonly cfg: MistralConfig) {}

  async extractPgn(imageBase64: string, mimeType: string): Promise<string> {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.model,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: _prompt },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
            ],
          },
        ],
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Mistral API error', res.status, errBody)
      throw new Error(_mistralErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const pgn: string = (data?.choices?.[0]?.message?.content ?? '').trim()
    if (!pgn) throw new Error('empty_model_output')
    return pgn
  }
}

export type GroqConfig = { apiKey: string; model: string }

export class GroqProvider implements PgnProvider {
  constructor(private readonly cfg: GroqConfig) {}

  async extractPgn(imageBase64: string, mimeType: string): Promise<string> {
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.model,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: _prompt },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
            ],
          },
        ],
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Groq API error', res.status, errBody)
      throw new Error(_groqErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const pgn: string = (data?.choices?.[0]?.message?.content ?? '').trim()
    if (!pgn) throw new Error('empty_model_output')
    return pgn
  }
}

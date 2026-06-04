export interface FenData {
  fen: string
}

export interface FenProvider {
  extractFen(imageBase64: string, mimeType: string): Promise<FenData>
}

const _fenResponseSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    fen: { type: 'string' },
  },
  required: ['fen'],
} as const

const _prompt = [
  'You are a chess position recognition engine.',
  'Given an image of a chess board (diagram, screenshot, or photograph), identify all piece positions and return the FEN string for the position.',
  'Rules:',
  '- To determine board orientation: if the image shows coordinate labels (files a-h and ranks 1-8), use them as the authoritative reference — rank 1 is white\'s back rank and rank 8 is black\'s back rank regardless of which side is at the bottom of the image.',
  '- If no coordinate labels are visible, assume white pieces are at the bottom of the board.',
  '- White pieces are visually lighter (white, cream, or outlined); black pieces are visually darker (black, dark gray, or filled). Use this to correctly assign piece colors to every individual piece.',
  '- Return ONLY a JSON object with a single "fen" key containing the complete FEN string.',
  '- The FEN must include all six fields: piece placement, active color, castling availability, en passant target square, halfmove clock, fullmove number.',
  '- Use "w" for active color if unclear.',
  '- Use "-" for castling availability and en passant target if unclear.',
  '- Use "0" and "1" for halfmove clock and fullmove number.',
  '- Example output: {"fen": "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1"}',
].join('\n')

function _parseFenData(content: string): FenData {
  const stripped = content.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim()
  let parsed: unknown
  try {
    parsed = JSON.parse(stripped)
  } catch {
    throw new Error('invalid_json')
  }
  const obj = parsed as Record<string, unknown>
  if (typeof obj?.fen !== 'string' || !obj.fen.trim()) throw new Error('schema_mismatch')
  return { fen: obj.fen.trim() }
}

function _classifyHttpError(
  status: number,
  body: string,
  hints: { unavailable: string[]; notFound: string[]; quota: string[] },
): string {
  const n = body.toLowerCase()
  if (status === 503 || hints.unavailable.some((h) => n.includes(h))) return 'provider_unavailable'
  if (status === 404 || hints.notFound.some((h) => n.includes(h))) return 'model_not_found'
  if (status === 429 || hints.quota.some((h) => n.includes(h))) return 'quota_exceeded'
  return 'extraction_failed'
}

const _googleHints = {
  unavailable: ['"status": "unavailable"'],
  notFound: ['not found', 'not supported'],
  quota: ['resource_exhausted', 'quota'],
}

const _openRouterHints = {
  unavailable: ['unavailable'],
  notFound: ['not found', 'unknown model'],
  quota: ['rate limit', 'quota', 'billing', 'credit'],
}

const _groqHints = {
  unavailable: ['service unavailable'],
  notFound: ['model not found', 'does not exist'],
  quota: ['rate limit', 'quota'],
}

export type GoogleConfig = { apiKey: string; model: string }

export class GoogleProvider implements FenProvider {
  constructor(private readonly cfg: GoogleConfig) {}

  async extractFen(imageBase64: string, mimeType: string): Promise<FenData> {
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
          generationConfig: { response_mime_type: 'application/json' },
        }),
      },
    )

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Google API error — status:', res.status, '— body:', errBody)
      throw new Error(_classifyHttpError(res.status, errBody, _googleHints))
    }

    const data = await res.json()
    const content: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseFenData(content)
  }
}

export type OpenRouterConfig = { apiKey: string; model: string }

export class OpenRouterProvider implements FenProvider {
  constructor(private readonly cfg: OpenRouterConfig) {}

  async extractFen(imageBase64: string, mimeType: string): Promise<FenData> {
    const res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
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
        response_format: {
          type: 'json_schema',
          json_schema: { name: 'chess_fen', strict: true, schema: _fenResponseSchema },
        },
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('OpenRouter API error', res.status, errBody)
      throw new Error(_classifyHttpError(res.status, errBody, _openRouterHints))
    }

    const data = await res.json()
    const content: string = data?.choices?.[0]?.message?.content ?? ''
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseFenData(content)
  }
}

export type GroqConfig = { apiKey: string; model: string }

export class GroqProvider implements FenProvider {
  constructor(private readonly cfg: GroqConfig) {}

  async extractFen(imageBase64: string, mimeType: string): Promise<FenData> {
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
        response_format: { type: 'json_object' },
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Groq API error', res.status, errBody)
      throw new Error(_classifyHttpError(res.status, errBody, _groqHints))
    }

    const data = await res.json()
    const content: string = data?.choices?.[0]?.message?.content ?? ''
    if (!content.trim()) throw new Error('empty_model_output')
    return _parseFenData(content)
  }
}

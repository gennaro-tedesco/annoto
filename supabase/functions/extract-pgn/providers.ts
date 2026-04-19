export interface PgnData {
  headers: Record<string, string>
  moves: string
}

export interface PgnProvider {
  extractPgn(imageBase64: string, mimeType: string): Promise<PgnData>
}

const _pgnResponseSchema = {
  type: 'object',
  additionalProperties: false,
  properties: {
    headers: {
      type: 'object',
      additionalProperties: false,
      properties: {
        White: { type: 'string' },
        Black: { type: 'string' },
        Event: { type: 'string' },
        Site: { type: 'string' },
        Date: { type: 'string' },
        Round: { type: 'string' },
        Result: { type: 'string' },
      },
      required: ['White', 'Black', 'Event', 'Site', 'Date', 'Round', 'Result'],
    },
    moves: { type: 'string' },
  },
  required: ['headers', 'moves'],
} as const

const _prompt = [
  'You are a chess scoresheet transcription engine.',
  'Given the image of a handwritten or printed chess scoresheet, extract the game information and moves and return them as a JSON object with this exact structure:',
  '{',
  '  "headers": {',
  '    "White": "player name or ?",',
  '    "Black": "player name or ?",',
  '    "Event": "tournament name or ?",',
  '    "Site": "location or ?",',
  '    "Date": "YYYY.MM.DD or ?",',
  '    "Round": "round number or ?",',
  '    "Result": "1-0 or 0-1 or 1/2-1/2 or *"',
  '  },',
  '  "moves": "1. e4 e5 2. Nf3 Nc6 ..."',
  '}',
  'Rules:',
  '- Use Standard Algebraic Notation (SAN) for every move in the moves field.',
  '- Include move numbers (e.g. 1. e4 e5 2. Nf3 Nc6).',
  "- If a move is illegible use '?' as a placeholder (e.g. 1. e4 ?).",
  '- If a header value is not visible on the scoresheet use "?" as the value.',
  '- Date must be in YYYY.MM.DD format if present.',
  '- Result must be one of: "1-0", "0-1", "1/2-1/2", or "*".',
  '- Output ONLY the JSON object, nothing else.',
].join('\n')

function _parsePgnData(content: string): PgnData {
  const stripped = content.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/, '').trim()
  let parsed: unknown
  try {
    parsed = JSON.parse(stripped)
  } catch {
    throw new Error('invalid_json')
  }
  const obj = parsed as Record<string, unknown>
  if (typeof obj?.moves !== 'string') throw new Error('schema_mismatch')
  const headers = (obj.headers as Record<string, string>) ?? {}
  return { headers, moves: obj.moves }
}

function _messageContentToString(content: unknown): string {
  if (typeof content == 'string') return content
  if (content && typeof content == 'object') return JSON.stringify(content)
  return ''
}

function _responseFormatJsonSchema() {
  return {
    type: 'json_schema',
    json_schema: {
      name: 'chess_scoresheet',
      strict: true,
      schema: _pgnResponseSchema,
    },
  }
}

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

  async extractPgn(imageBase64: string, mimeType: string): Promise<PgnData> {
    return this._extractWithInlineData(imageBase64, mimeType, 'empty_model_output')
  }

  private async _extractWithInlineData(
    dataBase64: string,
    mimeType: string,
    emptyResultCode: string,
  ): Promise<PgnData> {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.cfg.model}:generateContent?key=${this.cfg.apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { inline_data: { mime_type: mimeType, data: dataBase64 } },
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
      const code = _googleErrorCode(res.status, errBody)
      console.error('Google API error — resolved code:', code)
      throw new Error(code)
    }

    const data = await res.json()
    console.log('Google API response', JSON.stringify(data).slice(0, 500))
    const content: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
    if (!content.trim()) {
      throw new Error(emptyResultCode)
    }
    try {
      return _parsePgnData(content)
    } catch (err) {
      if (emptyResultCode == 'empty_model_output') {
        throw new Error('invalid_model_output')
      }
      throw err
    }
  }
}

export type MistralConfig = { apiKey: string; extractionModel: string }

export class MistralProvider implements PgnProvider {
  constructor(private readonly cfg: MistralConfig) {}

  async extractPgn(imageBase64: string, mimeType: string): Promise<PgnData> {
    const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.cfg.apiKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        model: this.cfg.extractionModel,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'text', text: _prompt },
              { type: 'image_url', image_url: { url: `data:${mimeType};base64,${imageBase64}` } },
            ],
          },
        ],
        response_format: _responseFormatJsonSchema(),
        temperature: 0,
      }),
    })

    if (!res.ok) {
      const errBody = await res.text()
      console.error('Mistral API error', res.status, errBody)
      throw new Error(_mistralErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content = _messageContentToString(data?.choices?.[0]?.message?.content)
    if (!content.trim()) throw new Error('empty_model_output')
    return _parsePgnData(content)
  }
}

export type GroqConfig = { apiKey: string; model: string }

export class GroqProvider implements PgnProvider {
  constructor(private readonly cfg: GroqConfig) {}

  async extractPgn(imageBase64: string, mimeType: string): Promise<PgnData> {
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
      throw new Error(_groqErrorCode(res.status, errBody))
    }

    const data = await res.json()
    const content: string = data?.choices?.[0]?.message?.content ?? ''
    if (!content.trim()) throw new Error('empty_model_output')
    return _parsePgnData(content)
  }
}

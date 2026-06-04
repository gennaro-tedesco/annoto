import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getProvider } from './config.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const MAX_BYTES = 10 * 1024 * 1024

Deno.serve(async (req: Request) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) return reply({ error: 'unauthorized' }, 401)

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  })
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()
  if (authError || !user) return reply({ error: 'unauthorized' }, 401)

  const { image, mimeType, provider: providerName, model } = await req.json()
  if (!image) return reply({ error: 'empty_input' }, 400)
  if ((image.length * 3) / 4 > MAX_BYTES) return reply({ error: 'payload_too_large' }, 413)

  const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp']
  if (mimeType && !allowedMimeTypes.includes(mimeType)) {
    return reply({ error: 'invalid_mime_type' }, 400)
  }

  const provider = getProvider(providerName, model)

  try {
    const data = await provider.extractFen(image, mimeType ?? 'image/jpeg')
    return reply({ fen: data.fen })
  } catch (err) {
    console.error('extract-fen caught error:', err)
    const message = err instanceof Error ? err.message : 'unknown_error'
    return reply({ error: message }, 502)
  }
})

function reply(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

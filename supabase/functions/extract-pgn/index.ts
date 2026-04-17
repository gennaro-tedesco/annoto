const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

const PROMPT = `You are a chess scoresheet transcription engine.

Given the image of a handwritten or printed chess scoresheet, extract all the moves and return them as a single valid PGN string.

Rules:
- Use Standard Algebraic Notation (SAN) for every move.
- Include move numbers (e.g. 1. e4 e5 2. Nf3 Nc6).
- If a move is illegible, use '?' as a placeholder (e.g. 1. e4 ?).
- Do not include any commentary, annotations, headers, or result tags.
- Output ONLY the raw move-text PGN, nothing else. Example: 1. e4 e5 2. Nf3 Nc6 3. Bb5 a6`;

Deno.serve(async (req) => {
  try {
    const { image, mimeType } = await req.json();

    const geminiRes = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: mimeType, data: image } },
            ],
          },
        ],
      }),
    });

    const geminiData = await geminiRes.json();
    const pgn: string =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text?.trim() ?? "";

    return new Response(JSON.stringify({ pgn }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

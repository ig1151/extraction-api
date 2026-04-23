const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const MODEL = 'anthropic/claude-sonnet-4-5';

export interface ExtractionResult {
  data: Record<string, unknown>;
  confidence: number;
  missing_fields: string[];
}

export async function extractWithClaude(
  text: string,
  schema: Record<string, string>,
  context: string
): Promise<ExtractionResult> {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) throw new Error('OPENROUTER_API_KEY not set');

  const fieldList = Object.entries(schema)
    .map(([key, type]) => `- ${key} (${type})`)
    .join('\n');

  const prompt = `You are a precise data extraction engine. Extract the following fields from the text below.
Context: ${context}
Fields to extract:
${fieldList}
Rules:
- Return ONLY a valid JSON object with the exact field names listed above
- Use null for any field you cannot find
- For arrays, return an empty array [] if nothing found
- Do not add extra fields
- Do not include markdown or explanation
Text to extract from:
"""
${text.slice(0, 8000)}
"""
Return only the JSON object:`;

  const response = await fetch(OPENROUTER_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 1000,
      messages: [{ role: 'user', content: prompt }],
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`OpenRouter error: ${response.status} ${err}`);
  }

  const data = await response.json() as { choices: { message: { content: string } }[] };
  const content = data.choices[0].message.content ?? '{}';

  let parsed: Record<string, unknown> = {};
  try {
    parsed = JSON.parse(content.replace(/```json|```/g, '').trim());
  } catch {
    parsed = {};
  }

  const expectedFields = Object.keys(schema);
  const missingFields = expectedFields.filter(f => parsed[f] === null || parsed[f] === undefined || parsed[f] === '');
  const filledFields = expectedFields.length - missingFields.length;
  const confidence = expectedFields.length > 0
    ? parseFloat((filledFields / expectedFields.length).toFixed(2))
    : 0;

  return { data: parsed, confidence, missing_fields: missingFields };
}

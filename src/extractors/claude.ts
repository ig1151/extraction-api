import axios from 'axios';

const ANTHROPIC_API = 'https://api.anthropic.com/v1/messages';

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
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error('ANTHROPIC_API_KEY not set');

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

  const res = await axios.post(
    ANTHROPIC_API,
    {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1000,
      messages: [{ role: 'user', content: prompt }],
    },
    {
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      timeout: 30000,
    }
  );

  const content = res.data.content[0]?.text ?? '{}';
  let parsed: Record<string, unknown> = {};

  try {
    parsed = JSON.parse(content.replace(/```json|```/g, '').trim());
  } catch {
    parsed = {};
  }

  // Calculate confidence and missing fields
  const expectedFields = Object.keys(schema);
  const missingFields = expectedFields.filter(f => parsed[f] === null || parsed[f] === undefined || parsed[f] === '');
  const filledFields = expectedFields.length - missingFields.length;
  const confidence = expectedFields.length > 0
    ? parseFloat((filledFields / expectedFields.length).toFixed(2))
    : 0;

  return { data: parsed, confidence, missing_fields: missingFields };
}

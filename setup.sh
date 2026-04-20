#!/bin/bash
set -e

echo "🚀 Setting up Extraction API..."

mkdir -p src/routes src/extractors

cat > package.json << 'ENDPACKAGE'
{
  "name": "extraction-api",
  "version": "1.0.0",
  "description": "Task-specific AI extraction APIs — leads, invoices, resumes and contracts from any text.",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "ts-node-dev --respawn --transpile-only src/index.ts",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "joi": "^17.11.0"
  },
  "devDependencies": {
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/node": "^20.10.0",
    "ts-node-dev": "^2.0.0",
    "typescript": "^5.3.2"
  }
}
ENDPACKAGE

cat > tsconfig.json << 'ENDTSCONFIG'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
ENDTSCONFIG

cat > render.yaml << 'ENDRENDER'
services:
  - type: web
    name: extraction-api
    env: node
    buildCommand: npm install && npm run build
    startCommand: node dist/index.js
    healthCheckPath: /v1/health
    envVars:
      - key: NODE_ENV
        value: production
      - key: PORT
        value: 10000
      - key: ANTHROPIC_API_KEY
        sync: false
ENDRENDER

cat > .gitignore << 'ENDGITIGNORE'
node_modules/
dist/
.env
*.log
ENDGITIGNORE

cat > .env.example << 'ENDENV'
ANTHROPIC_API_KEY=your_key_here
ENDENV

cat > src/logger.ts << 'ENDLOGGER'
export const logger = {
  info: (obj: unknown, msg?: string) =>
    console.log(JSON.stringify({ level: 'info', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
  warn: (obj: unknown, msg?: string) =>
    console.warn(JSON.stringify({ level: 'warn', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
  error: (obj: unknown, msg?: string) =>
    console.error(JSON.stringify({ level: 'error', ...(typeof obj === 'object' ? obj : { data: obj }), msg })),
};
ENDLOGGER

cat > src/extractors/claude.ts << 'ENDCLAUDE'
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
ENDCLAUDE

cat > src/extractors/schemas.ts << 'ENDSCHEMAS'
export const SCHEMAS: Record<string, { fields: Record<string, string>; context: string }> = {
  lead: {
    context: 'Extract contact and company information for a sales lead',
    fields: {
      name: 'string',
      email: 'string',
      phone: 'string',
      company: 'string',
      role: 'string',
      linkedin: 'string',
      location: 'string',
      industry: 'string',
    },
  },
  invoice: {
    context: 'Extract invoice and billing information',
    fields: {
      invoice_number: 'string',
      vendor_name: 'string',
      vendor_email: 'string',
      client_name: 'string',
      issue_date: 'string',
      due_date: 'string',
      total_amount: 'number',
      currency: 'string',
      line_items: 'array of {description, quantity, unit_price, total}',
      tax_amount: 'number',
      payment_terms: 'string',
    },
  },
  resume: {
    context: 'Extract professional profile and career information from a resume or CV',
    fields: {
      name: 'string',
      email: 'string',
      phone: 'string',
      location: 'string',
      linkedin: 'string',
      summary: 'string',
      skills: 'array of strings',
      experience: 'array of {company, role, start_date, end_date, description}',
      education: 'array of {institution, degree, field, graduation_year}',
      certifications: 'array of strings',
    },
  },
  contract: {
    context: 'Extract key terms and parties from a legal contract or agreement',
    fields: {
      contract_type: 'string',
      party_one: 'string',
      party_two: 'string',
      effective_date: 'string',
      expiration_date: 'string',
      value: 'number',
      currency: 'string',
      governing_law: 'string',
      payment_terms: 'string',
      termination_clause: 'string',
      key_obligations: 'array of strings',
    },
  },
  receipt: {
    context: 'Extract purchase and payment information from a receipt',
    fields: {
      merchant_name: 'string',
      merchant_address: 'string',
      date: 'string',
      total_amount: 'number',
      currency: 'string',
      items: 'array of {name, quantity, price}',
      tax: 'number',
      payment_method: 'string',
      receipt_number: 'string',
    },
  },
};
ENDSCHEMAS

cat > src/routes/extract.ts << 'ENDEXTRACT'
import { Router, Request, Response } from 'express';
import Joi from 'joi';
import { extractWithClaude } from '../extractors/claude';
import { SCHEMAS } from '../extractors/schemas';
import { logger } from '../logger';

const router = Router();

const textSchema = Joi.object({
  text: Joi.string().min(10).max(50000).required(),
});

const customSchema = Joi.object({
  text: Joi.string().min(10).max(50000).required(),
  schema: Joi.object().pattern(Joi.string(), Joi.string()).min(1).max(30).required(),
  context: Joi.string().max(200).optional(),
});

async function handleExtraction(
  req: Request,
  res: Response,
  schemaName: string
): Promise<void> {
  const { error, value } = textSchema.validate(req.body);
  if (error) {
    res.status(400).json({ error: 'Validation failed', details: error.details[0].message });
    return;
  }

  const schema = SCHEMAS[schemaName];
  if (!schema) {
    res.status(400).json({ error: `Unknown schema: ${schemaName}` });
    return;
  }

  const start = Date.now();
  try {
    const result = await extractWithClaude(value.text, schema.fields, schema.context);
    logger.info({ schema: schemaName, confidence: result.confidence, missing: result.missing_fields.length }, 'Extraction complete');
    res.json({
      schema: schemaName,
      ...result,
      latency_ms: Date.now() - start,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Extraction failed';
    logger.error({ schema: schemaName, err }, 'Extraction failed');
    res.status(500).json({ error: 'Extraction failed', details: message });
  }
}

// Prebuilt schema endpoints
router.post('/extract/lead', (req, res) => handleExtraction(req, res, 'lead'));
router.post('/extract/invoice', (req, res) => handleExtraction(req, res, 'invoice'));
router.post('/extract/resume', (req, res) => handleExtraction(req, res, 'resume'));
router.post('/extract/contract', (req, res) => handleExtraction(req, res, 'contract'));
router.post('/extract/receipt', (req, res) => handleExtraction(req, res, 'receipt'));

// Custom schema endpoint
router.post('/extract/custom', async (req: Request, res: Response) => {
  const { error, value } = customSchema.validate(req.body);
  if (error) {
    res.status(400).json({ error: 'Validation failed', details: error.details[0].message });
    return;
  }

  const start = Date.now();
  try {
    const result = await extractWithClaude(
      value.text,
      value.schema,
      value.context ?? 'Extract the requested fields from the text'
    );
    logger.info({ schema: 'custom', confidence: result.confidence }, 'Custom extraction complete');
    res.json({
      schema: 'custom',
      ...result,
      latency_ms: Date.now() - start,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Extraction failed';
    logger.error({ err }, 'Custom extraction failed');
    res.status(500).json({ error: 'Extraction failed', details: message });
  }
});

// List schemas
router.get('/schemas', (_req: Request, res: Response) => {
  const schemas = Object.entries(SCHEMAS).map(([name, schema]) => ({
    name,
    context: schema.context,
    fields: Object.keys(schema.fields),
    field_count: Object.keys(schema.fields).length,
  }));
  res.json({ schemas, count: schemas.length });
});

export default router;
ENDEXTRACT

cat > src/routes/docs.ts << 'ENDDOCS'
import { Router, Request, Response } from 'express';
const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Extraction API</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 860px; margin: 40px auto; padding: 0 20px; background: #0f0f0f; color: #e0e0e0; }
    h1 { color: #7c3aed; } h2 { color: #a78bfa; border-bottom: 1px solid #333; padding-bottom: 8px; }
    pre { background: #1a1a1a; padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; }
    code { color: #c084fc; }
    .badge { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 12px; margin-right: 8px; color: white; }
    .get { background: #065f46; } .post { background: #7c3aed; }
    table { width: 100%; border-collapse: collapse; } td, th { padding: 8px 12px; border: 1px solid #333; text-align: left; }
    th { background: #1a1a1a; }
  </style>
</head>
<body>
  <h1>Extraction API</h1>
  <p>Task-specific AI extraction APIs — leads, invoices, resumes, contracts and custom schemas.</p>
  <h2>Endpoints</h2>
  <table>
    <tr><th>Method</th><th>Path</th><th>Description</th></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/lead</td><td>Extract lead contact data</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/invoice</td><td>Extract invoice and billing data</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/resume</td><td>Extract resume and career data</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/contract</td><td>Extract contract terms and parties</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/receipt</td><td>Extract receipt and purchase data</td></tr>
    <tr><td><span class="badge post">POST</span></td><td>/v1/extract/custom</td><td>Extract with your own schema</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/schemas</td><td>List available schemas</td></tr>
    <tr><td><span class="badge get">GET</span></td><td>/v1/health</td><td>Health check</td></tr>
  </table>
  <h2>Example — Lead Extraction</h2>
  <pre>POST /v1/extract/lead
{ "text": "John Smith, CTO at Stripe. Reach him at john@stripe.com or +1-415-555-1234." }</pre>
  <h2>Example — Custom Schema</h2>
  <pre>POST /v1/extract/custom
{
  "text": "Order #1234 placed by Jane Doe on April 1st for $299.",
  "schema": {
    "order_number": "string",
    "customer_name": "string",
    "date": "string",
    "amount": "number"
  },
  "context": "Extract order information"
}</pre>
  <p><a href="/openapi.json" style="color:#a78bfa">OpenAPI JSON</a></p>
</body>
</html>`);
});

export default router;
ENDDOCS

cat > src/routes/openapi.ts << 'ENDOPENAPI'
import { Router, Request, Response } from 'express';
const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.json({
    openapi: '3.0.0',
    info: {
      title: 'Extraction API',
      version: '1.0.0',
      description: 'Task-specific AI extraction APIs — leads, invoices, resumes, contracts and custom schemas.',
    },
    servers: [{ url: 'https://extraction-api.onrender.com' }],
    paths: {
      '/v1/extract/lead': { post: { summary: 'Extract lead data', responses: { '200': { description: 'Extracted lead' } } } },
      '/v1/extract/invoice': { post: { summary: 'Extract invoice data', responses: { '200': { description: 'Extracted invoice' } } } },
      '/v1/extract/resume': { post: { summary: 'Extract resume data', responses: { '200': { description: 'Extracted resume' } } } },
      '/v1/extract/contract': { post: { summary: 'Extract contract data', responses: { '200': { description: 'Extracted contract' } } } },
      '/v1/extract/receipt': { post: { summary: 'Extract receipt data', responses: { '200': { description: 'Extracted receipt' } } } },
      '/v1/extract/custom': { post: { summary: 'Extract with custom schema', responses: { '200': { description: 'Extracted data' } } } },
      '/v1/schemas': { get: { summary: 'List available schemas', responses: { '200': { description: 'Schema list' } } } },
      '/v1/health': { get: { summary: 'Health check', responses: { '200': { description: 'OK' } } } },
    },
  });
});

export default router;
ENDOPENAPI

cat > src/index.ts << 'ENDINDEX'
import 'dotenv/config';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import { logger } from './logger';
import extractRouter from './routes/extract';
import docsRouter from './routes/docs';
import openapiRouter from './routes/openapi';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(compression());
app.use(express.json());
app.use(rateLimit({ windowMs: 60_000, max: 60, standardHeaders: true, legacyHeaders: false }));

app.get('/', (_req, res) => {
  res.json({
    service: 'extraction-api',
    version: '1.0.0',
    description: 'Task-specific AI extraction APIs — leads, invoices, resumes, contracts and custom schemas.',
    status: 'ok',
    docs: '/docs',
    health: '/v1/health',
    endpoints: {
      lead: 'POST /v1/extract/lead',
      invoice: 'POST /v1/extract/invoice',
      resume: 'POST /v1/extract/resume',
      contract: 'POST /v1/extract/contract',
      receipt: 'POST /v1/extract/receipt',
      custom: 'POST /v1/extract/custom',
      schemas: 'GET /v1/schemas',
    },
  });
});

app.get('/v1/health', (_req, res) => {
  res.json({ status: 'ok', service: 'extraction-api', timestamp: new Date().toISOString() });
});

app.use('/v1', extractRouter);
app.use('/docs', docsRouter);
app.use('/openapi.json', openapiRouter);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found', path: req.path });
});

app.listen(PORT, () => {
  logger.info({ port: PORT }, 'Extraction API running');
});
ENDINDEX

echo "✅ All files created!"
echo "Next: npm install && npm run dev"
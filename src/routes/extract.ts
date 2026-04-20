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

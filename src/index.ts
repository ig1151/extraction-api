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

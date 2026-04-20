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

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

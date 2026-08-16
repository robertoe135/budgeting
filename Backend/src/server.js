import express from 'express';
import { pathToFileURL } from 'node:url';
import { config } from './config.js';
import { requireApiKey } from './middleware/auth.js';
import { healthRouter } from './routes/health.js';
import { webhookRouter } from './routes/webhook.js';
import { linkTokenRouter } from './routes/linkToken.js';
import { exchangeTokenRouter } from './routes/exchangeToken.js';
import { itemsRouter } from './routes/items.js';
import { accountsRouter } from './routes/accounts.js';
import { transactionsRouter } from './routes/transactions.js';

export function createApp() {
  const app = express();

  // Capture the raw request body alongside the parsed one — the webhook route needs the
  // untouched bytes to verify Plaid's signature (re-serialized JSON won't hash the same).
  app.use(express.json({
    verify: (req, res, buf) => {
      req.rawBody = buf;
    }
  }));

  app.use(healthRouter);
  app.use(webhookRouter); // unauthenticated by design; see routes/webhook.js

  app.use(requireApiKey);
  app.use(linkTokenRouter);
  app.use(exchangeTokenRouter);
  app.use(itemsRouter);
  app.use(accountsRouter);
  app.use(transactionsRouter);

  // Centralized fallback so a thrown/rejected route handler never leaks a stack trace to the
  // client (Express 5 forwards async errors here automatically).
  app.use((err, req, res, next) => {
    console.error('Unhandled error:', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

// Robust against being invoked as `node src/server.js` (a relative path) — a plain
// `file://${process.argv[1]}` string comparison fails in that case since process.argv[1]
// isn't URL-encoded/absolute, which meant this never actually ran under a normal `npm start`.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const app = createApp();
  app.listen(config.port, () => {
    console.log(`Budgeting backend listening on :${config.port} (Plaid env: ${config.plaid.env})`);
  });
}

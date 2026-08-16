import { Router } from 'express';

export const healthRouter = Router();

// Deliberately unauthenticated — used for host platform health checks (Railway/Render ping this).
healthRouter.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

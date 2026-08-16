import { Router } from 'express';
import { verifyPlaidWebhook } from '../webhookVerify.js';
import { updateStatus } from '../itemsStore.js';

export const webhookRouter = Router();

/**
 * POST /webhook — called by Plaid, not the app, so it deliberately sits outside the
 * requireApiKey middleware. Signature verification (see webhookVerify.js) is what stands in
 * for auth here instead.
 *
 * There's no server push to the app in this v1 (no APNs wiring yet), so most webhook codes
 * are just logged. The one thing worth acting on server-side is ITEM_LOGIN_REQUIRED, so the
 * next GET /items call can tell the app to prompt a re-link before a sync silently starts
 * failing for that institution.
 */
webhookRouter.post('/webhook', async (req, res) => {
  try {
    await verifyPlaidWebhook(req.rawBody, req.get('plaid-verification'));
  } catch (error) {
    console.error('Rejected webhook (failed verification):', error.message);
    return res.status(401).json({ error: 'Invalid webhook signature' });
  }

  const { webhook_type: type, webhook_code: code, item_id: itemId, error: itemError } = req.body ?? {};
  console.log(`Plaid webhook: ${type}/${code} for item ${itemId ?? '(none)'}`);

  if (type === 'ITEM' && code === 'ERROR' && itemError?.error_code === 'ITEM_LOGIN_REQUIRED' && itemId) {
    updateStatus(itemId, 'login_required');
  }
  if (type === 'ITEM' && code === 'LOGIN_REPAIRED' && itemId) {
    updateStatus(itemId, 'active');
  }

  // SYNC_UPDATES_AVAILABLE just means "new data is ready" — the app pulls it on its own
  // schedule via GET /transactions/sync, so there's nothing further to do here.
  res.status(200).json({ acknowledged: true });
});

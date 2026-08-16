import { Router } from 'express';
import { plaidClient } from '../plaidClient.js';
import { upsertItem } from '../itemsStore.js';
import { handlePlaidError } from '../plaidError.js';

export const exchangeTokenRouter = Router();

/**
 * POST /link/exchange
 * Body: { publicToken, institutionId?, institutionName? } — the latter two come straight off
 * Link's onSuccess(metadata) callback in the app and are stored only for display purposes.
 */
exchangeTokenRouter.post('/link/exchange', async (req, res) => {
  const { publicToken, institutionId, institutionName } = req.body ?? {};
  if (!publicToken) {
    return res.status(400).json({ error: 'publicToken is required' });
  }

  try {
    const response = await plaidClient.itemPublicTokenExchange({ public_token: publicToken });
    const { access_token: accessToken, item_id: itemId } = response.data;

    upsertItem({ itemId, accessToken, institutionId, institutionName });

    res.json({ itemId, institutionName: institutionName ?? null });
  } catch (error) {
    handlePlaidError(res, error, 'Failed to exchange public token');
  }
});

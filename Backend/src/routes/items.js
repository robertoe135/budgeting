import { Router } from 'express';
import { plaidClient } from '../plaidClient.js';
import { listActiveItems, getItem, removeItem } from '../itemsStore.js';
import { handlePlaidError } from '../plaidError.js';

export const itemsRouter = Router();

/** GET /items — linked institutions, never including the access token itself. */
itemsRouter.get('/items', (req, res) => {
  const items = listActiveItems().map(({ itemId, institutionId, institutionName, status, createdAt }) => ({
    itemId,
    institutionId,
    institutionName,
    status, // 'active' | 'login_required' — the app should prompt a re-link (update mode) when not 'active'
    createdAt
  }));
  res.json({ items });
});

/** DELETE /items/:itemId — revokes access at Plaid and stops syncing this institution. */
itemsRouter.delete('/items/:itemId', async (req, res) => {
  const item = getItem(req.params.itemId);
  if (!item) return res.status(404).json({ error: 'Unknown item' });

  try {
    await plaidClient.itemRemove({ access_token: item.accessToken });
  } catch (error) {
    // If Plaid already considers the item gone, don't block removing it locally too.
    if (error?.response?.data?.error_code !== 'ITEM_NOT_FOUND') {
      return handlePlaidError(res, error, 'Failed to unlink item at Plaid');
    }
  }

  removeItem(item.itemId);
  res.status(204).end();
});

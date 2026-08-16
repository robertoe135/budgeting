import { Router } from 'express';
import { plaidClient } from '../plaidClient.js';
import { config } from '../config.js';
import { getItem } from '../itemsStore.js';
import { handlePlaidError } from '../plaidError.js';

export const linkTokenRouter = Router();

// This app supports exactly one Plaid end-user; a fixed client_user_id is fine at this scale.
const CLIENT_USER_ID = 'budgeting-app-single-user';

/**
 * POST /link/token
 * Body: {} to link a brand-new institution, or { itemId } to re-link an existing one in
 * Plaid's "update mode" (used after an ITEM_LOGIN_REQUIRED webhook/status).
 */
linkTokenRouter.post('/link/token', async (req, res) => {
  const { itemId } = req.body ?? {};

  const request = {
    user: { client_user_id: CLIENT_USER_ID },
    client_name: 'Budgeting',
    language: 'en',
    country_codes: config.plaid.countryCodes,
    ...(config.plaid.redirectUri ? { redirect_uri: config.plaid.redirectUri } : {}),
    ...(config.plaid.webhookUrl ? { webhook: config.plaid.webhookUrl } : {})
  };

  if (itemId) {
    const item = getItem(itemId);
    if (!item) return res.status(404).json({ error: `Unknown item ${itemId}` });
    request.access_token = item.accessToken;
  } else {
    request.products = config.plaid.products;
  }

  try {
    const response = await plaidClient.linkTokenCreate(request);
    res.json({ linkToken: response.data.link_token, expiration: response.data.expiration });
  } catch (error) {
    handlePlaidError(res, error, 'Failed to create link token');
  }
});

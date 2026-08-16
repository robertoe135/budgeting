import { Router } from 'express';
import { plaidClient } from '../plaidClient.js';
import { listActiveItems, updateStatus } from '../itemsStore.js';

export const accountsRouter = Router();

/**
 * GET /accounts — live balances across every linked institution.
 *
 * Fetched fresh from Plaid on every call rather than cached: at single-user, personal-app
 * scale the extra API call is cheap and it keeps balances always current with zero sync logic.
 * Revisit (cache + rely on webhooks) if you ever add more users or poll more than a few
 * times an hour.
 */
accountsRouter.get('/accounts', async (req, res) => {
  const items = listActiveItems();
  const accounts = [];
  const itemErrors = [];

  await Promise.all(items.map(async (item) => {
    try {
      const response = await plaidClient.accountsBalanceGet({ access_token: item.accessToken });
      for (const account of response.data.accounts) {
        accounts.push({
          itemId: item.itemId,
          institutionName: item.institutionName,
          accountId: account.account_id,
          name: account.name,
          officialName: account.official_name,
          mask: account.mask,
          type: account.type,
          subtype: account.subtype,
          balances: {
            available: account.balances.available,
            current: account.balances.current,
            limit: account.balances.limit,
            isoCurrencyCode: account.balances.iso_currency_code
          }
        });
      }
    } catch (error) {
      const errorCode = error?.response?.data?.error_code;
      if (errorCode === 'ITEM_LOGIN_REQUIRED') {
        updateStatus(item.itemId, 'login_required');
      }
      console.error(`Failed to fetch balances for item ${item.itemId}:`, errorCode ?? error);
      itemErrors.push({ itemId: item.itemId, institutionName: item.institutionName, errorCode: errorCode ?? 'UNKNOWN' });
    }
  }));

  res.json({ accounts, itemErrors });
});

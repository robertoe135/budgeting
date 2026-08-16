import { Router } from 'express';
import { plaidClient } from '../plaidClient.js';
import { listActiveItems, updateCursor, updateStatus } from '../itemsStore.js';

export const transactionsRouter = Router();

/**
 * Plaid's sign convention: positive `amount` = money leaving the account (an expense),
 * negative = money coming in (a refund/credit/income). The iOS app stores amount as always
 * positive plus a separate expense/income `kind` — flip the sign here so the client doesn't
 * have to know about Plaid's convention at all.
 */
function toTransactionDTO(t, item) {
  return {
    itemId: item.itemId,
    accountId: t.account_id,
    transactionId: t.transaction_id,
    amount: Math.abs(t.amount),
    kind: t.amount >= 0 ? 'expense' : 'income',
    isoCurrencyCode: t.iso_currency_code,
    date: t.date,
    merchantName: t.merchant_name || t.name,
    pending: t.pending,
    // "detailed" (e.g. FOOD_AND_DRINK_GROCERIES) is far more useful for auto-categorization
    // than "primary" (FOOD_AND_DRINK) alone; fall back progressively for older/legacy items
    // that don't have Personal Finance Category enrichment.
    category: t.personal_finance_category?.detailed
      ?? t.personal_finance_category?.primary
      ?? t.category?.[0]
      ?? null
  };
}

/**
 * GET /transactions/sync
 *
 * Pulls new/changed/removed transactions since each linked item's last stored cursor, using
 * Plaid's recommended `/transactions/sync` cursor pagination (loops until has_more is false),
 * then persists the new cursor per item. Call this whenever the app wants fresh data — on
 * foreground, pull-to-refresh, or a background refresh task. There's no server-push in this
 * v1; the app is the one that decides when to ask.
 */
transactionsRouter.get('/transactions/sync', async (req, res) => {
  const items = listActiveItems();
  const added = [];
  const modified = [];
  const removed = [];
  const itemErrors = [];

  await Promise.all(items.map(async (item) => {
    try {
      let cursor = item.cursor ?? undefined;
      let hasMore = true;

      while (hasMore) {
        const response = await plaidClient.transactionsSync({
          access_token: item.accessToken,
          cursor,
          count: 250
        });
        const data = response.data;
        added.push(...data.added.map((t) => toTransactionDTO(t, item)));
        modified.push(...data.modified.map((t) => toTransactionDTO(t, item)));
        removed.push(...data.removed.map((t) => ({ itemId: item.itemId, transactionId: t.transaction_id })));
        cursor = data.next_cursor;
        hasMore = data.has_more;
      }

      updateCursor(item.itemId, cursor);
    } catch (error) {
      const errorCode = error?.response?.data?.error_code;
      if (errorCode === 'ITEM_LOGIN_REQUIRED') {
        updateStatus(item.itemId, 'login_required');
      }
      console.error(`Failed to sync transactions for item ${item.itemId}:`, errorCode ?? error);
      itemErrors.push({ itemId: item.itemId, institutionName: item.institutionName, errorCode: errorCode ?? 'UNKNOWN' });
    }
  }));

  res.json({ added, modified, removed, itemErrors });
});

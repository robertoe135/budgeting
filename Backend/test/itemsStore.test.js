import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

process.env.API_KEY ??= 'test-api-key';
process.env.TOKEN_ENCRYPTION_KEY ??= 'b'.repeat(64);
process.env.PLAID_CLIENT_ID ??= 'test-client-id';
process.env.PLAID_SECRET ??= 'test-secret';
process.env.PLAID_ENV ??= 'sandbox';
process.env.DATA_DIR = mkdtempSync(join(tmpdir(), 'budgeting-test-'));

const store = await import('../src/itemsStore.js');

test('upsertItem + getItem round-trips and decrypts the access token', () => {
  store.upsertItem({ itemId: 'item-1', accessToken: 'access-token-1', institutionId: 'ins_1', institutionName: 'Chase' });
  const item = store.getItem('item-1');
  assert.equal(item.accessToken, 'access-token-1');
  assert.equal(item.institutionName, 'Chase');
  assert.equal(item.status, 'active');
  assert.equal(item.cursor, null);
});

test('upsertItem is idempotent on item_id (updates rather than duplicating)', () => {
  store.upsertItem({ itemId: 'item-2', accessToken: 'first-token', institutionName: 'Amex' });
  store.upsertItem({ itemId: 'item-2', accessToken: 'rotated-token', institutionName: 'Amex' });

  const matches = store.listActiveItems().filter((i) => i.itemId === 'item-2');
  assert.equal(matches.length, 1);
  assert.equal(matches[0].accessToken, 'rotated-token');
});

test('updateCursor persists the sync cursor for later calls', () => {
  store.upsertItem({ itemId: 'item-3', accessToken: 'token-3', institutionName: 'Apple Card' });
  store.updateCursor('item-3', 'cursor-abc');
  assert.equal(store.getItem('item-3').cursor, 'cursor-abc');
});

test('updateStatus + removeItem: removed items drop out of listActiveItems', () => {
  store.upsertItem({ itemId: 'item-4', accessToken: 'token-4', institutionName: 'Chase' });

  store.updateStatus('item-4', 'login_required');
  assert.equal(store.getItem('item-4').status, 'login_required');

  store.removeItem('item-4');
  assert.equal(store.getItem('item-4').status, 'removed');
  assert.ok(!store.listActiveItems().some((i) => i.itemId === 'item-4'));
});

test('getItem returns null for an unknown id', () => {
  assert.equal(store.getItem('does-not-exist'), null);
});

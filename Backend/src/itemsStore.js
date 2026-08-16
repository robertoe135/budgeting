import { db } from './db.js';
import { encrypt, decrypt } from './crypto.js';

/** Row shape returned to callers, with the access token decrypted and ready to use. */
function hydrate(row) {
  if (!row) return null;
  return {
    itemId: row.item_id,
    accessToken: decrypt(row.access_token_encrypted),
    institutionId: row.institution_id,
    institutionName: row.institution_name,
    cursor: row.cursor,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

export function upsertItem({ itemId, accessToken, institutionId, institutionName }) {
  const now = new Date().toISOString();
  db.prepare(`
    INSERT INTO items (item_id, access_token_encrypted, institution_id, institution_name, cursor, status, created_at, updated_at)
    VALUES (?, ?, ?, ?, NULL, 'active', ?, ?)
    ON CONFLICT(item_id) DO UPDATE SET
      access_token_encrypted = excluded.access_token_encrypted,
      institution_id = excluded.institution_id,
      institution_name = excluded.institution_name,
      status = 'active',
      updated_at = excluded.updated_at
  `).run(itemId, encrypt(accessToken), institutionId ?? null, institutionName ?? null, now, now);
}

export function listItems() {
  const rows = db.prepare('SELECT * FROM items ORDER BY created_at ASC').all();
  return rows.map(hydrate);
}

export function listActiveItems() {
  const rows = db.prepare("SELECT * FROM items WHERE status != 'removed' ORDER BY created_at ASC").all();
  return rows.map(hydrate);
}

export function getItem(itemId) {
  const row = db.prepare('SELECT * FROM items WHERE item_id = ?').get(itemId);
  return hydrate(row);
}

export function updateCursor(itemId, cursor) {
  db.prepare('UPDATE items SET cursor = ?, updated_at = ? WHERE item_id = ?')
    .run(cursor, new Date().toISOString(), itemId);
}

export function updateStatus(itemId, status) {
  db.prepare('UPDATE items SET status = ?, updated_at = ? WHERE item_id = ?')
    .run(status, new Date().toISOString(), itemId);
}

export function removeItem(itemId) {
  db.prepare("UPDATE items SET status = 'removed', updated_at = ? WHERE item_id = ?")
    .run(new Date().toISOString(), itemId);
}

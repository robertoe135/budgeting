import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { config } from './config.js';

// node:sqlite is still an experimental Node API (stable since ~Node 22), but it's built in —
// no native module compilation step, which matters a lot for a one-click deploy to
// Railway/Render. Swap this file for better-sqlite3 or a Postgres client later if you outgrow
// single-user scale; nothing outside this file knows how rows are stored.
mkdirSync(config.dataDir, { recursive: true });
export const db = new DatabaseSync(join(config.dataDir, 'budgeting.db'));

db.exec(`
  CREATE TABLE IF NOT EXISTS items (
    item_id TEXT PRIMARY KEY,
    access_token_encrypted TEXT NOT NULL,
    institution_id TEXT,
    institution_name TEXT,
    cursor TEXT,
    status TEXT NOT NULL DEFAULT 'active', -- active | login_required | removed
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
`);

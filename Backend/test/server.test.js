import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

process.env.API_KEY = 'integration-test-key';
process.env.TOKEN_ENCRYPTION_KEY = 'c'.repeat(64);
process.env.PLAID_CLIENT_ID = 'test-client-id';
process.env.PLAID_SECRET = 'test-secret';
process.env.PLAID_ENV = 'sandbox';
process.env.DATA_DIR = mkdtempSync(join(tmpdir(), 'budgeting-test-'));

const { createApp } = await import('../src/server.js');

async function withServer(fn) {
  const server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const { port } = server.address();
  try {
    await fn(`http://127.0.0.1:${port}`);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

test('GET /health works without auth', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { status: 'ok' });
  });
});

test('protected routes reject requests with no Authorization header', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`);
    assert.equal(res.status, 401);
  });
});

test('protected routes reject the wrong API key', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`, { headers: { Authorization: 'Bearer wrong-key' } });
    assert.equal(res.status, 401);
  });
});

test('protected routes accept the correct API key', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/items`, { headers: { Authorization: `Bearer ${process.env.API_KEY}` } });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { items: [] });
  });
});

test('webhook rejects a request with no Plaid-Verification header', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ webhook_type: 'ITEM', webhook_code: 'ERROR' })
    });
    assert.equal(res.status, 401);
  });
});

test('webhook rejects a malformed Plaid-Verification header', async () => {
  await withServer(async (base) => {
    const res = await fetch(`${base}/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Plaid-Verification': 'not-a-jwt' },
      body: JSON.stringify({ webhook_type: 'ITEM', webhook_code: 'ERROR' })
    });
    assert.equal(res.status, 401);
  });
});

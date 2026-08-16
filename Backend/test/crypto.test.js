import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.API_KEY ??= 'test-api-key';
process.env.TOKEN_ENCRYPTION_KEY ??= 'a'.repeat(64);
process.env.PLAID_CLIENT_ID ??= 'test-client-id';
process.env.PLAID_SECRET ??= 'test-secret';
process.env.PLAID_ENV ??= 'sandbox';
process.env.DATA_DIR ??= './data/test-crypto';

const { encrypt, decrypt } = await import('../src/crypto.js');

test('encrypt/decrypt round-trips a Plaid access token', () => {
  const secret = 'access-sandbox-super-secret-token';
  const encrypted = encrypt(secret);
  assert.notEqual(encrypted, secret);
  assert.equal(decrypt(encrypted), secret);
});

test('encrypting the same value twice produces different ciphertext (random IV)', () => {
  const a = encrypt('access-sandbox-token');
  const b = encrypt('access-sandbox-token');
  assert.notEqual(a, b);
});

test('decrypt rejects a tampered ciphertext', () => {
  const encrypted = encrypt('access-sandbox-token');
  const [iv, tag] = encrypted.split(':');
  const tampered = [iv, tag, Buffer.from('tampered-bytes').toString('base64')].join(':');
  assert.throws(() => decrypt(tampered));
});

test('decrypt rejects a malformed payload', () => {
  assert.throws(() => decrypt('not-a-valid-payload'));
});

import { randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { config } from './config.js';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // recommended IV size for GCM

const key = Buffer.from(config.tokenEncryptionKey, 'hex');

/**
 * Encrypts a string (e.g. a Plaid access token) for storage at rest.
 * Returns `iv:authTag:ciphertext`, each base64-encoded.
 */
export function encrypt(plaintext) {
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return [iv.toString('base64'), authTag.toString('base64'), ciphertext.toString('base64')].join(':');
}

/** Reverses {@link encrypt}. Throws if the payload was tampered with or the key is wrong. */
export function decrypt(payload) {
  const [ivB64, authTagB64, ciphertextB64] = payload.split(':');
  if (!ivB64 || !authTagB64 || !ciphertextB64) {
    throw new Error('Malformed encrypted payload');
  }
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(authTagB64, 'base64'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(ciphertextB64, 'base64')),
    decipher.final()
  ]);
  return plaintext.toString('utf8');
}

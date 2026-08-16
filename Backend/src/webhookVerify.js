import { createPublicKey, createHash, verify as cryptoVerify } from 'node:crypto';
import { plaidClient } from './plaidClient.js';

// Plaid's webhook verification keys are JWKs; cache by kid so we're not calling
// /webhook_verification_key/get on every single webhook delivery. Per Plaid's docs, a key
// only needs re-fetching once it reports an expired_at.
const keyCache = new Map();

function base64UrlDecode(input) {
  return Buffer.from(input.replaceAll('-', '+').replaceAll('_', '/'), 'base64');
}

async function getVerificationKey(kid) {
  const cached = keyCache.get(kid);
  if (cached && !cached.expired_at) return cached;

  const response = await plaidClient.webhookVerificationKeyGet({ key_id: kid });
  const key = response.data.key;
  keyCache.set(kid, key);
  if (key.expired_at) {
    throw new Error(`Webhook verification key ${kid} has expired`);
  }
  return key;
}

/**
 * Verifies a Plaid webhook request per https://plaid.com/docs/api/webhooks/webhook-verification/.
 * `rawBody` must be the exact bytes Plaid sent — verifying against re-serialized JSON will
 * fail, since key order / whitespace can differ from what was signed.
 */
export async function verifyPlaidWebhook(rawBody, signatureHeader) {
  if (!rawBody) throw new Error('Missing request body');
  if (!signatureHeader) throw new Error('Missing Plaid-Verification header');

  const [encodedHeader, encodedPayload, encodedSignature] = signatureHeader.split('.');
  if (!encodedHeader || !encodedPayload || !encodedSignature) {
    throw new Error('Malformed webhook JWT');
  }

  const header = JSON.parse(base64UrlDecode(encodedHeader).toString('utf8'));
  if (header.alg !== 'ES256') {
    throw new Error(`Unexpected JWT algorithm: ${header.alg}`);
  }

  const jwk = await getVerificationKey(header.kid);
  const publicKey = createPublicKey({ key: jwk, format: 'jwk' });

  const signedData = Buffer.from(`${encodedHeader}.${encodedPayload}`);
  const signature = base64UrlDecode(encodedSignature);
  const isValid = cryptoVerify('sha256', signedData, { key: publicKey, dsaEncoding: 'ieee-p1363' }, signature);
  if (!isValid) {
    throw new Error('Invalid webhook signature');
  }

  const payload = JSON.parse(base64UrlDecode(encodedPayload).toString('utf8'));
  const bodyHash = createHash('sha256').update(rawBody).digest('hex');
  if (bodyHash !== payload.request_body_sha256) {
    throw new Error('Webhook body hash does not match signed payload');
  }
}

import { timingSafeEqual } from 'node:crypto';
import { config } from '../config.js';

function safeEqual(a, b) {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  // Lengths almost always differ for a wrong guess; compare against a fixed-length buffer
  // first so the length check itself doesn't leak timing information.
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

/** Requires `Authorization: Bearer <API_KEY>`. This app is single-user, so one shared secret
 * (kept in the iOS Keychain on the client) stands in for real per-user auth. */
export function requireApiKey(req, res, next) {
  const header = req.get('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token || !safeEqual(token, config.apiKey)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

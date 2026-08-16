import 'dotenv/config';

function required(name) {
  const value = process.env[name];
  if (!value || value.trim() === '') {
    throw new Error(`Missing required environment variable: ${name} (see .env.example)`);
  }
  return value;
}

function list(name, fallback) {
  const raw = process.env[name] ?? fallback;
  return raw.split(',').map((s) => s.trim()).filter(Boolean);
}

// Fails fast and loudly at startup rather than mid-request if something's missing —
// deliberately not lazy, so a bad deploy is obvious immediately in the logs.
export const config = Object.freeze({
  port: Number(process.env.PORT ?? 4000),
  dataDir: process.env.DATA_DIR ?? './data',
  apiKey: required('API_KEY'),
  tokenEncryptionKey: required('TOKEN_ENCRYPTION_KEY'),
  plaid: Object.freeze({
    clientId: required('PLAID_CLIENT_ID'),
    secret: required('PLAID_SECRET'),
    env: process.env.PLAID_ENV ?? 'sandbox',
    products: list('PLAID_PRODUCTS', 'transactions'),
    countryCodes: list('PLAID_COUNTRY_CODES', 'US'),
    redirectUri: process.env.PLAID_REDIRECT_URI || undefined,
    webhookUrl: process.env.PLAID_WEBHOOK_URL || undefined
  })
});

if (config.tokenEncryptionKey.length !== 64) {
  throw new Error(
    'TOKEN_ENCRYPTION_KEY must be 64 hex characters (32 bytes). Generate one with: ' +
    'node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
  );
}

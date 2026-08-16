# Budgeting Backend

A small Node.js/Express service that holds your Plaid access token(s) and exposes the handful
of endpoints the iOS app needs to link a bank, pull balances, and sync transactions. This
exists because Plaid access tokens must never live on the device — see the root README for why.

Single-user by design: one shared API key stands in for real per-user auth, and there's no
users table. If you ever want multiple people using this, that's the piece to add first.

## What it does (and doesn't) do

- Creates Plaid `link_token`s (including "update mode" for re-linking an institution that needs
  fresh login).
- Exchanges Link's `public_token` for an `access_token` and stores it **encrypted at rest**
  (AES-256-GCM), keyed by a `TOKEN_ENCRYPTION_KEY` you generate and keep off GitHub.
- Fetches live account balances and syncs transactions (`/transactions/sync`, cursor-based —
  Plaid's current recommended API, not the older `/transactions/get`).
- Verifies Plaid's webhook signature (JWT, ES256) before trusting anything it POSTs.
- Does **not** push anything to the app — no APNs wiring yet. The app pulls fresh data on
  foreground / pull-to-refresh / right after linking. A `SYNC_UPDATES_AVAILABLE` webhook arriving
  is logged but doesn't do anything more than that today; see "Adding push later" below.

## Requirements

- Node.js 22.5+ (uses the built-in `node:sqlite` module — no native compilation step, which
  keeps deploys simple, but it's still an experimental Node API; see "On node:sqlite" below).
- A Plaid account with API keys (you mentioned you already have production keys — see
  "Sandbox vs Production" before pointing this at them).

## Local setup

```sh
cd Backend
npm install
cp .env.example .env
```

Fill in `.env`:
- `PLAID_CLIENT_ID` / `PLAID_SECRET` — from the [Plaid dashboard](https://dashboard.plaid.com/team-settings/keys).
- `API_KEY` — generate with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`.
  This is what you'll paste into the app's Bank Connections screen.
- `TOKEN_ENCRYPTION_KEY` — generate the same way. **Back this up somewhere safe outside the
  repo** (a password manager is fine) — if you lose it, every stored access token becomes
  undecryptable and you'll need to unlink and re-link every account.
- Leave `PLAID_REDIRECT_URI` and `PLAID_WEBHOOK_URL` blank for local development.

```sh
npm start        # or: npm run dev  (auto-restarts on file changes)
npm test          # 15 tests: crypto round-trip, item storage, auth wiring, webhook rejection
```

`npm test` doesn't call the real Plaid API (no sandbox/production credentials are exercised) —
it covers everything that doesn't require live network: encryption correctness, the SQLite
item store, API-key auth on every route, and webhook signature rejection paths. Route handlers
that call Plaid directly (`/link/token`, `/link/exchange`, `/accounts`, `/transactions/sync`)
are exercised by hand against sandbox/production once you have real credentials.

## Sandbox vs Production

You mentioned you're on a Plaid **production** trial. A couple of things that matters for:

- Production Plaid charges per connected Item once you're past the trial — check current
  pricing on your Plaid dashboard before linking a lot of accounts.
- Set `PLAID_ENV=production` in `.env` (or `sandbox` if you want to test end-to-end first with
  fake bank logins — Plaid's sandbox has test institutions with username `user_good` /
  password `pass_good`). It's worth doing a full sandbox run-through before pointing this at
  your real Chase/Amex/Apple Card logins, just to shake out any integration bugs safely.
- Chase is an OAuth institution, which means Plaid Link redirects out to Chase's own login page
  and back. That requires `PLAID_REDIRECT_URI` to be set and registered in your Plaid dashboard
  (Team Settings → API → Allowed redirect URIs) as an **exact match**, and the iOS app needs a
  matching Universal Link association — this is the one piece of setup that's genuinely fiddly.
  Amex and Apple Card don't use OAuth redirect and will work without it.

## Deploying (Railway or Render)

Both work the same way at a high level:

1. Push this repo to GitHub (already done) and connect the service to it, with **Backend/** as
   the root/working directory.
2. Set the start command to `npm start` (build command `npm install` — most platforms detect
   this automatically from `package.json`).
3. Add every variable from `.env.example` as an environment variable/secret in the platform's
   dashboard — **do not** commit `.env`.
4. **Persistent storage matters.** `DATA_DIR` needs to point at a volume that survives restarts
   and redeploys, or every deploy forgets your linked accounts:
   - **Railway**: add a Volume, mount it (e.g. at `/data`), set `DATA_DIR=/data`.
   - **Render**: Disks require a paid instance type (the free web service tier is ephemeral, no
     disk support) — set `DATA_DIR=/var/data` and add a Disk mounted there. If you want to stay
     on Render's free tier, swap `src/db.js` for a free external Postgres instead (Render offers
     one) — nothing outside that one file knows how items are stored.
5. Once deployed, set `PLAID_WEBHOOK_URL` to `https://<your-deployed-host>/webhook` and
   redeploy — this is what lets Plaid tell you when re-authentication is needed
   (`ITEM_LOGIN_REQUIRED`) between the app's own polling.
6. Paste the deployed HTTPS URL and your `API_KEY` into the app's Accounts → Bank Connections
   screen.

## On `node:sqlite`

This uses Node's built-in SQLite module instead of `better-sqlite3` specifically to avoid a
native-module compile step on deploy — one less thing to go wrong on a free-tier host. It's
still marked experimental by Node (prints a warning on startup; harmless). If you outgrow
single-user scale or want to be off an experimental API, swap `src/db.js` and
`src/itemsStore.js` for `better-sqlite3` or Postgres — those two files are the only place
storage is implemented; nothing else in the codebase knows or cares.

## Adding push later

Right now "sync" only happens when the app asks (foreground, pull-to-refresh, right after
linking). If you want the weekly-limit notification to fire the moment a transaction posts
rather than the next time you open the app, the next step is: register an APNs device token
from the app, store it alongside the item(s), and have the `SYNC_UPDATES_AVAILABLE` /
`ITEM_LOGIN_REQUIRED` webhook handlers in `src/routes/webhook.js` send a silent push instead of
just logging. Not built here — the webhook signature verification and item-status bookkeeping
it would build on top of already are.

## Security notes

- Access tokens are encrypted at rest, never logged, and never sent to the client — the app
  only ever sees this backend's own API responses.
- All app-facing routes require `Authorization: Bearer <API_KEY>`; `/health` and `/webhook` are
  the only unauthenticated routes, and `/webhook` verifies Plaid's own JWT signature instead.
- Rotate `API_KEY` any time you suspect it leaked (update the env var, redeploy, and re-paste it
  into the app). Rotating `TOKEN_ENCRYPTION_KEY` is destructive — see above — so treat that one
  as closer to a recovery-phrase than a password.

# Budgeting

A SwiftUI iOS app for tracking accounts, weekly spending limits, fixed monthly
charges, and a savings goal — with local spending alerts and a home-screen
widget. Transactions can be logged by hand, or synced automatically via an
optional Plaid-backed bank link.

## Features

- **Accounts** — tracks Chase Checking/Savings, Amex Checking/Savings, and
  credit cards (Amex Card, Apple Card, Chase Prime Visa) out of the box;
  add, edit, or remove any account (institution × checking/savings/credit
  card). Credit cards track balance owed and an optional credit limit.
- **Weekly spending limits** — set a limit manually, or let the app
  auto-suggest one from `(monthly income − fixed charges − savings goal) /
  weeks in the month`. The Dashboard shows a live progress bar and flags
  the week red the moment you go over.
- **Fixed monthly charges** — track subscriptions, rent, insurance,
  utilities, etc., each with an amount, category, frequency (monthly/
  weekly/bi-weekly/annually, normalized to a monthly equivalent) and an
  optional linked payment account. Their total feeds directly into the
  weekly budget math.
- **Savings goal** — set a monthly or per-paycheck savings target; the
  remainder after fixed charges and savings is what spreads across the
  weeks as your discretionary spending limit.
- **In-phone notifications** — local alerts when you cross 80% of your
  weekly limit and when you go over, plus a weekly reset reminder. No
  server or push infrastructure required for this part.
- **Home-screen widget** — `BudgetingWidget` shows this week's spending
  progress (small, medium, and Lock Screen circular sizes), reading from
  the same data via an App Group.
- **Optional Plaid bank sync** — link Chase/Amex/Apple Card via Plaid Link
  and have balances and transactions sync in automatically instead of (or
  alongside) typing them in by hand. See "Plaid integration" below —
  requires standing up the small backend in `Backend/`, since Plaid access
  tokens can't live on the device. Entirely optional; the app works fully
  manually without it.

## Project structure

```
project.yml                  # XcodeGen spec — source of truth for the Xcode project
Shared/                       # Compiled into the app, the widget, and the tests
  Models/                     # SwiftData @Model types: Account, Transaction, RecurringCharge, BudgetSettings
  Engine/BudgetEngine.swift   # Pure budget math (weekly limit, spend totals, over-limit checks)
  Persistence/                # App Group–backed shared ModelContainer + first-launch seeding
  Utilities/Formatting.swift  # Currency formatting
Budgeting/                    # App target
  BudgetingApp.swift
  Notifications/NotificationManager.swift
  Services/                   # Plaid API client, sync orchestration, Keychain/backend config
  Views/                      # Dashboard, Accounts, Spending, Fixed Charges, Budget tabs, Plaid linking UI
  Assets.xcassets, Info.plist, Budgeting.entitlements
BudgetingWidget/               # WidgetKit extension target
  BudgetingWidgetBundle.swift, WeeklySpendingWidget.swift
  Info.plist, BudgetingWidget.entitlements
BudgetingTests/
  BudgetEngineTests.swift     # Unit tests for the budget math
Backend/                      # Optional Node.js/Express service that talks to Plaid on the app's behalf
  src/, test/, README.md      # See Backend/README.md for setup, deploy, and security notes
```

## Opening the project

This repo ships Swift source and an [XcodeGen](https://github.com/yonaskolb/XcodeGen)
spec (`project.yml`) rather than a committed `.xcodeproj`, so the project
file always stays in sync with the file layout. On a Mac with Xcode:

```sh
brew install xcodegen
cd budgeting
xcodegen generate
open Budgeting.xcodeproj
```

Then in Xcode, for **both** the `Budgeting` and `BudgetingWidgetExtension`
targets:

1. Select your Apple Developer team under **Signing & Capabilities**.
2. Confirm the **App Groups** capability lists
   `group.com.robertoesquenazi.budgeting` (already wired up via the
   `.entitlements` files; if you change the bundle ID prefix, update the
   group identifier in `Shared/Persistence/SharedModelContainer.swift` and
   both `.entitlements` files to match).
3. Add a real app icon in `Budgeting/Assets.xcassets/AppIcon.appiconset`
   (a placeholder slot is included but empty).
4. `project.yml` declares a Swift Package dependency on Plaid's `LinkKit`
   (`plaid-link-ios-spm`) for the Plaid linking screen — Xcode will resolve
   it automatically on first open as long as you're online.

Requires iOS 17+ (SwiftData) and Xcode 15+.

## Running tests

```sh
xcodebuild test -scheme Budgeting -destination 'platform=iOS Simulator,name=iPhone 15'
```

`BudgetEngineTests` covers the weekly-limit calculation, manual overrides,
over-limit detection, and per-paycheck savings goal conversion.

## Plaid integration

Bank linking is optional and off by default — until you configure a backend
URL and API key in the app (Accounts → the link icon in the toolbar → Bank
Connections), everything works exactly as a manual-entry tracker.

To turn it on:

1. Stand up the backend in `Backend/` (Railway/Render both work well;
   Node.js + Express + a small SQLite store) — full instructions in
   [`Backend/README.md`](Backend/README.md), including how it keeps your
   Plaid access token off the device entirely, sandbox-vs-production
   guidance, and the one Chase-specific wrinkle (OAuth redirect URI setup).
2. In the app, open **Accounts → 🔗 → Bank Connections** and enter the
   deployed backend's HTTPS URL and the API key you generated for it.
3. Tap **Link a New Bank Account** to launch Plaid Link.

Once linked: **Sync Now** (or just foregrounding the app) pulls fresh
balances and transactions and folds them into the same SwiftData store the
rest of the app reads — so the weekly limit, notifications, and widget all
pick up Plaid-sourced transactions the same way they'd pick up manually
logged ones. A Plaid-linked account's balance/institution/type become
read-only in its edit screen (they're overwritten on the next sync anyway);
you can still rename it or edit individual transactions' categories.

There's no push in this v1 — new data shows up next time you open the app
or tap Sync Now, not the instant a charge posts. `Backend/README.md`
outlines what adding APNs push later would look like.

## Notes & possible next steps

- Manually-entered account balances update automatically when you log a
  *new* transaction against an account; editing an existing manual
  transaction does not re-sync the balance (adjust it directly on the
  account's edit screen if needed). Plaid-linked account balances instead
  come straight from Plaid on every sync.
- "Discretionary" spend (what counts against the weekly limit) defaults
  off for Housing/Utilities/Subscriptions/Insurance categories and on for
  everything else, but is overridable per transaction — including
  Plaid-sourced ones, whose category is auto-set once on import and left
  alone on later syncs so your edits stick.
- Natural extensions if you want to grow this further: real push
  notifications (see `Backend/README.md`'s "Adding push later"), multi-user
  auth if this ever needs to serve more than one person, iCloud sync via
  SwiftData's CloudKit integration for the manual/local data, and richer
  charts/trends.

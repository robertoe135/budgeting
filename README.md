# Budgeting

A SwiftUI iOS app for tracking accounts, weekly spending limits, fixed monthly
charges, and a savings goal — with local spending alerts and a home-screen
widget.

This is a **manual-entry** tracker: it does not link to your banks (no
Plaid/bank API integration). You log balances and transactions yourself,
and everything else — the weekly budget, alerts, and widget — is computed
on-device from that data.

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
  server or push infrastructure required.
- **Home-screen widget** — `BudgetingWidget` shows this week's spending
  progress (small, medium, and Lock Screen circular sizes), reading from
  the same data via an App Group.

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
  Views/                      # Dashboard, Accounts, Spending, Fixed Charges, Budget tabs
  Assets.xcassets, Info.plist, Budgeting.entitlements
BudgetingWidget/               # WidgetKit extension target
  BudgetingWidgetBundle.swift, WeeklySpendingWidget.swift
  Info.plist, BudgetingWidget.entitlements
BudgetingTests/
  BudgetEngineTests.swift     # Unit tests for the budget math
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

Requires iOS 17+ (SwiftData) and Xcode 15+.

## Running tests

```sh
xcodebuild test -scheme Budgeting -destination 'platform=iOS Simulator,name=iPhone 15'
```

`BudgetEngineTests` covers the weekly-limit calculation, manual overrides,
over-limit detection, and per-paycheck savings goal conversion.

## Notes & possible next steps

- Account balances update automatically when you log a *new* transaction
  against an account; editing an existing transaction does not re-sync the
  balance (adjust it directly on the account's edit screen if needed).
- "Discretionary" spend (what counts against the weekly limit) defaults
  off for Housing/Utilities/Subscriptions/Insurance categories and on for
  everything else, but is overridable per transaction.
- Natural extensions if you want to grow this: bank linking (Plaid) to
  auto-import transactions, iCloud sync via SwiftData's CloudKit
  integration, richer charts/trends, and push (rather than local-only)
  notifications for multi-device setups.

import Foundation
import SwiftData

/// Orchestrates talking to our backend and folding the result into SwiftData. The backend is
/// the source of truth for anything Plaid-derived; this just keeps the local store in sync
/// with it. There's no push in this v1 — call `syncAll` whenever fresh data is wanted (app
/// foreground, pull-to-refresh, right after linking a new account).
@MainActor
final class PlaidSyncService: ObservableObject {
    static let shared = PlaidSyncService()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let client: PlaidAPIClient

    // `= nil` rather than `= PlaidAPIClient()`: default *argument expressions* are evaluated
    // in a nonisolated context even when the initializer they belong to is on a @MainActor
    // type, so a default that directly constructs another @MainActor type doesn't type-check.
    // Constructing it in the init body instead — which genuinely does run isolated — sidesteps
    // that entirely. (Same fix applied to PlaidAPIClient's own init below.)
    init(client: PlaidAPIClient? = nil) {
        self.client = client ?? PlaidAPIClient()
    }

    /// Call right after Link's onSuccess: exchanges the public token server-side, then pulls
    /// the newly-linked account(s) and their transaction history immediately.
    func completeLink(publicToken: String, institutionId: String?, institutionName: String?, context: ModelContext) async {
        do {
            _ = try await client.exchangePublicToken(publicToken, institutionId: institutionId, institutionName: institutionName)
            try await syncAll(context: context)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func syncAll(context: ModelContext) async throws -> Bool {
        guard BackendConfig.shared.isConfigured else { return false }
        isSyncing = true
        defer { isSyncing = false }

        do {
            async let accountsResponseTask = client.fetchAccounts()
            async let transactionsResponseTask = client.syncTransactions()

            let accountsResponse = try await accountsResponseTask
            upsertAccounts(accountsResponse.accounts, context: context)

            let transactionsResponse = try await transactionsResponseTask
            upsertTransactions(transactionsResponse, context: context)

            try context.save()
            lastSyncedAt = .now
            lastErrorMessage = nil
            return true
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Accounts

    private func upsertAccounts(_ dtos: [PlaidAccountDTO], context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        var byPlaidId = Dictionary(uniqueKeysWithValues: existing.compactMap { account -> (String, Account)? in
            account.plaidAccountId.map { ($0, account) }
        })
        var nextSortOrder = (existing.map(\.sortOrder).max() ?? -1) + 1

        for dto in dtos {
            let account = byPlaidId[dto.accountId] ?? {
                let created = Account(
                    name: dto.name,
                    institution: .from(plaidInstitutionName: dto.institutionName),
                    type: .from(plaidType: dto.type, subtype: dto.subtype),
                    sortOrder: nextSortOrder,
                    plaidAccountId: dto.accountId,
                    plaidItemId: dto.itemId
                )
                context.insert(created)
                byPlaidId[dto.accountId] = created
                nextSortOrder += 1
                return created
            }()

            account.name = dto.name
            account.plaidItemId = dto.itemId
            if account.type == .creditCard {
                // Plaid reports a credit card's "current" balance as the amount already owed.
                account.balance = dto.balances.current ?? account.balance
                account.creditLimit = dto.balances.limit ?? account.creditLimit
            } else {
                account.balance = dto.balances.current ?? dto.balances.available ?? account.balance
            }
        }
    }

    // MARK: - Transactions

    private func upsertTransactions(_ response: TransactionsSyncResponse, context: ModelContext) {
        guard !(response.added.isEmpty && response.modified.isEmpty && response.removed.isEmpty) else { return }

        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let accountsByPlaidId = Dictionary(uniqueKeysWithValues: accounts.compactMap { account -> (String, Account)? in
            account.plaidAccountId.map { ($0, account) }
        })

        let existingTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        var transactionsByPlaidId = Dictionary(uniqueKeysWithValues: existingTransactions.compactMap { transaction -> (String, Transaction)? in
            transaction.plaidTransactionId.map { ($0, transaction) }
        })

        for dto in response.added {
            guard transactionsByPlaidId[dto.transactionId] == nil else { continue }
            let transaction = Transaction(
                date: parseDate(dto.date),
                amount: dto.amount,
                merchant: dto.merchantName,
                account: accountsByPlaidId[dto.accountId],
                plaidTransactionId: dto.transactionId,
                isPending: dto.pending
            )
            applyCore(dto, to: transaction, accountsByPlaidId: accountsByPlaidId)
            // Only set category/discretionary defaults on first creation — never clobber a
            // category the user has since edited by hand.
            if let mapped = TransactionCategory.from(plaidCategory: dto.category) {
                transaction.category = mapped
                transaction.isDiscretionary = !TransactionCategory.fixedCategories.contains(mapped)
            }
            context.insert(transaction)
            transactionsByPlaidId[dto.transactionId] = transaction
        }

        for dto in response.modified {
            guard let transaction = transactionsByPlaidId[dto.transactionId] else { continue }
            applyCore(dto, to: transaction, accountsByPlaidId: accountsByPlaidId)
        }

        for removed in response.removed {
            guard let transaction = transactionsByPlaidId[removed.transactionId] else { continue }
            context.delete(transaction)
            transactionsByPlaidId[removed.transactionId] = nil
        }
    }

    /// Fields that can legitimately change on a pending → posted transition, applied on both
    /// create and update. Category is handled separately (create-only; see above).
    private func applyCore(_ dto: PlaidTransactionDTO, to transaction: Transaction, accountsByPlaidId: [String: Account]) {
        transaction.date = parseDate(dto.date)
        transaction.amount = dto.amount
        transaction.merchant = dto.merchantName
        transaction.kind = dto.kind == "income" ? .income : .expense
        transaction.isPending = dto.pending
        transaction.account = accountsByPlaidId[dto.accountId]
    }

    private func parseDate(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter.date(from: isoDate) ?? .now
    }
}

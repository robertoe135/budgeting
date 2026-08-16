import SwiftUI
import SwiftData

struct AddEditTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let transaction: Transaction?

    @State private var merchant = ""
    @State private var amountText = ""
    @State private var date = Date.now
    @State private var category: TransactionCategory = .other
    @State private var kind: TransactionKind = .expense
    @State private var account: Account?
    @State private var notes = ""
    @State private var isDiscretionary = true

    private var isNew: Bool { transaction == nil }

    var body: some View {
        Form {
            Section {
                TextField("Merchant / description", text: $merchant)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                Picker("Type", selection: $kind) {
                    Text("Expense").tag(TransactionKind.expense)
                    Text("Income").tag(TransactionKind.income)
                }
                .pickerStyle(.segmented)
            }

            Section("Categorize") {
                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Account", selection: $account) {
                    Text("None").tag(Account?.none)
                    ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
                }
                Toggle("Counts against weekly limit", isOn: $isDiscretionary)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
            }

            if !isNew {
                Section {
                    Button("Delete Transaction", role: .destructive) { delete() }
                }
            }
        }
        .navigationTitle(isNew ? "New Transaction" : "Edit Transaction")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(merchant.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountText) == nil)
            }
        }
        .onAppear(perform: populate)
        .onChange(of: category) { _, newValue in
            // Only auto-flip the default when creating a new entry; don't clobber an explicit
            // user override while editing.
            guard isNew else { return }
            isDiscretionary = !TransactionCategory.fixedCategories.contains(newValue)
        }
    }

    private func populate() {
        guard let transaction else { return }
        merchant = transaction.merchant
        amountText = String(format: "%.2f", transaction.amount)
        date = transaction.date
        category = transaction.category
        kind = transaction.kind
        account = transaction.account
        notes = transaction.notes
        isDiscretionary = transaction.isDiscretionary
    }

    private func save() {
        let amount = Double(amountText) ?? 0

        if let transaction {
            transaction.merchant = merchant
            transaction.amount = amount
            transaction.date = date
            transaction.category = category
            transaction.kind = kind
            transaction.account = account
            transaction.notes = notes
            transaction.isDiscretionary = isDiscretionary
        } else {
            let newTransaction = Transaction(
                date: date,
                amount: amount,
                merchant: merchant,
                notes: notes,
                category: category,
                kind: kind,
                isDiscretionary: isDiscretionary,
                account: account
            )
            context.insert(newTransaction)
            applyBalanceToAccount(amount: amount)
        }
        dismiss()
    }

    /// Nudges the manually-tracked account balance when a *new* transaction is logged.
    /// (Editing an existing transaction does not re-sync the balance — adjust the account's
    /// balance directly on its edit screen if needed.)
    private func applyBalanceToAccount(amount: Double) {
        guard let account else { return }
        let signedAmount = kind == .income ? amount : -amount
        if account.type == .creditCard {
            account.balance -= signedAmount
        } else {
            account.balance += signedAmount
        }
    }

    private func delete() {
        if let transaction { context.delete(transaction) }
        dismiss()
    }
}

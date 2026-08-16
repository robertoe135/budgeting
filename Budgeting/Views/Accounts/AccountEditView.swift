import SwiftUI
import SwiftData

struct AccountEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let account: Account?

    @State private var name = ""
    @State private var institution: Institution = .chase
    @State private var type: AccountType = .checking
    @State private var balanceText = ""
    @State private var creditLimitText = ""
    @State private var isArchived = false

    private var isNew: Bool { account == nil }
    private var isPlaidLinked: Bool { account?.isPlaidLinked ?? false }

    var body: some View {
        Form {
            if isPlaidLinked {
                Section {
                    Label("Linked via Plaid — balance and institution sync automatically and aren't editable here.", systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Details") {
                TextField("Account name", text: $name)
                Picker("Institution", selection: $institution) {
                    ForEach(Institution.allCases) { Text($0.rawValue).tag($0) }
                }
                .disabled(isPlaidLinked)
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { Text($0.rawValue).tag($0) }
                }
                .disabled(isPlaidLinked)
            }

            Section(type == .creditCard ? "Balance Owed" : "Current Balance") {
                TextField("0.00", text: $balanceText)
                    .keyboardType(.decimalPad)
                    .disabled(isPlaidLinked)
                if type == .creditCard {
                    TextField("Credit limit (optional)", text: $creditLimitText)
                        .keyboardType(.decimalPad)
                        .disabled(isPlaidLinked)
                }
            }

            if !isNew {
                Section {
                    Toggle("Archived", isOn: $isArchived)
                }
            }
        }
        .navigationTitle(isNew ? "New Account" : "Edit Account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let account else { return }
        name = account.name
        institution = account.institution
        type = account.type
        balanceText = String(format: "%.2f", account.balance)
        creditLimitText = account.creditLimit.map { String(format: "%.2f", $0) } ?? ""
        isArchived = account.isArchived
    }

    private func save() {
        if let account {
            account.name = name
            account.isArchived = isArchived
            // Plaid-linked accounts get institution/type/balance/creditLimit from the next
            // sync — editing them here would just be overwritten, so leave them alone.
            if !isPlaidLinked {
                account.institution = institution
                account.type = type
                account.balance = Double(balanceText) ?? 0
                account.creditLimit = type == .creditCard ? Double(creditLimitText) : nil
            }
        } else {
            let balance = Double(balanceText) ?? 0
            let creditLimit = type == .creditCard ? Double(creditLimitText) : nil
            let newAccount = Account(name: name, institution: institution, type: type, balance: balance, creditLimit: creditLimit)
            context.insert(newAccount)
        }
        dismiss()
    }
}

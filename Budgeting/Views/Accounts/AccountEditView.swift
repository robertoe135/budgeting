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

    var body: some View {
        Form {
            Section("Details") {
                TextField("Account name", text: $name)
                Picker("Institution", selection: $institution) {
                    ForEach(Institution.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Type", selection: $type) {
                    ForEach(AccountType.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            Section(type == .creditCard ? "Balance Owed" : "Current Balance") {
                TextField("0.00", text: $balanceText)
                    .keyboardType(.decimalPad)
                if type == .creditCard {
                    TextField("Credit limit (optional)", text: $creditLimitText)
                        .keyboardType(.decimalPad)
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
        let balance = Double(balanceText) ?? 0
        let creditLimit = type == .creditCard ? Double(creditLimitText) : nil

        if let account {
            account.name = name
            account.institution = institution
            account.type = type
            account.balance = balance
            account.creditLimit = creditLimit
            account.isArchived = isArchived
        } else {
            let newAccount = Account(name: name, institution: institution, type: type, balance: balance, creditLimit: creditLimit)
            context.insert(newAccount)
        }
        dismiss()
    }
}

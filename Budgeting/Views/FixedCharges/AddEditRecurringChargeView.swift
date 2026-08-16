import SwiftUI
import SwiftData

struct AddEditRecurringChargeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let charge: RecurringCharge?

    @State private var name = ""
    @State private var amountText = ""
    @State private var category: TransactionCategory = .subscriptions
    @State private var frequency: RecurringFrequency = .monthly
    @State private var dayOfMonth = 1
    @State private var isActive = true
    @State private var account: Account?

    private var isNew: Bool { charge == nil }

    var body: some View {
        Form {
            Section {
                TextField("Name (e.g. Netflix, Rent)", text: $name)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { Text($0.rawValue).tag($0) }
                }
                Stepper("Due on day \(dayOfMonth)", value: $dayOfMonth, in: 1...31)
            }

            Section {
                Picker("Payment Account", selection: $account) {
                    Text("None").tag(Account?.none)
                    ForEach(accounts) { Text($0.name).tag(Account?.some($0)) }
                }
                Toggle("Active", isOn: $isActive)
            }

            if !isNew {
                Section {
                    Button("Delete", role: .destructive) { delete() }
                }
            }
        }
        .navigationTitle(isNew ? "New Fixed Charge" : "Edit Fixed Charge")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(amountText) == nil)
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let charge else { return }
        name = charge.name
        amountText = String(format: "%.2f", charge.amount)
        category = charge.category
        frequency = charge.frequency
        dayOfMonth = charge.dayOfMonth
        isActive = charge.isActive
        account = charge.account
    }

    private func save() {
        let amount = Double(amountText) ?? 0

        if let charge {
            charge.name = name
            charge.amount = amount
            charge.category = category
            charge.frequency = frequency
            charge.dayOfMonth = dayOfMonth
            charge.isActive = isActive
            charge.account = account
        } else {
            let newCharge = RecurringCharge(name: name, amount: amount, category: category, frequency: frequency, dayOfMonth: dayOfMonth, isActive: isActive, account: account)
            context.insert(newCharge)
        }
        dismiss()
    }

    private func delete() {
        if let charge { context.delete(charge) }
        dismiss()
    }
}

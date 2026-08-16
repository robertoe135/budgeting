import SwiftUI
import SwiftData

struct BudgetSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsList: [BudgetSettings]
    @Query private var recurringCharges: [RecurringCharge]

    @State private var monthlyIncomeText = ""
    @State private var savingsGoalText = ""
    @State private var savingsGoalFrequency: SavingsGoalFrequency = .monthly
    @State private var payFrequency: PayFrequency = .monthly
    @State private var useManualLimit = false
    @State private var manualLimitText = ""
    @State private var weekStartsMonday = true
    @State private var didLoad = false

    private var settings: BudgetSettings { settingsList.first ?? BudgetSettings() }
    private var activeCharges: [RecurringCharge] { recurringCharges.filter { $0.isActive } }
    private var fixedTotal: Double { BudgetEngine.totalMonthlyFixedCharges(activeCharges) }

    /// A settings snapshot built from the in-progress form fields, used only to preview the
    /// suggested weekly limit live as the user types (not persisted until Save is tapped).
    private var previewSettings: BudgetSettings {
        BudgetSettings(
            monthlyIncome: Double(monthlyIncomeText) ?? 0,
            savingsGoalAmount: Double(savingsGoalText) ?? 0,
            savingsGoalFrequency: savingsGoalFrequency,
            payFrequency: payFrequency,
            weekStartsMonday: weekStartsMonday
        )
    }

    private var suggestedWeekly: Double {
        BudgetEngine.suggestedWeeklyLimit(settings: previewSettings, fixedCharges: activeCharges)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Income") {
                    TextField("Monthly income", text: $monthlyIncomeText)
                        .keyboardType(.decimalPad)
                    Picker("Pay schedule", selection: $payFrequency) {
                        ForEach(PayFrequency.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Savings Goal") {
                    TextField("Amount", text: $savingsGoalText)
                        .keyboardType(.decimalPad)
                    Picker("Frequency", selection: $savingsGoalFrequency) {
                        ForEach(SavingsGoalFrequency.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Fixed Monthly Charges") {
                    HStack {
                        Text("From Fixed Charges tab")
                        Spacer()
                        Text(fixedTotal.formattedCurrency)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Weekly Spending Limit") {
                    HStack {
                        Text("Suggested (auto-calculated)")
                        Spacer()
                        Text(suggestedWeekly.formattedCurrency)
                            .fontWeight(.semibold)
                    }
                    Text("Income minus fixed charges and your savings goal, split across this month's weeks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Set limit manually instead", isOn: $useManualLimit)
                    if useManualLimit {
                        TextField("Weekly limit", text: $manualLimitText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Week") {
                    Toggle("Week starts Monday", isOn: $weekStartsMonday)
                }

                Section("Notifications") {
                    Toggle("Enable spending alerts", isOn: settingsBinding(\.notificationsEnabled))
                    Toggle("Alert at 80% of weekly limit", isOn: settingsBinding(\.notifyAt80Percent))
                    Toggle("Alert when over weekly limit", isOn: settingsBinding(\.notifyAtOverLimit))
                }
            }
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: loadOnce)
        }
    }

    private func settingsBinding(_ keyPath: ReferenceWritableKeyPath<BudgetSettings, Bool>) -> Binding<Bool> {
        Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        let current = settings
        monthlyIncomeText = current.monthlyIncome == 0 ? "" : String(format: "%.2f", current.monthlyIncome)
        savingsGoalText = current.savingsGoalAmount == 0 ? "" : String(format: "%.2f", current.savingsGoalAmount)
        savingsGoalFrequency = SavingsGoalFrequency(rawValue: current.savingsGoalFrequency) ?? .monthly
        payFrequency = PayFrequency(rawValue: current.payFrequency) ?? .monthly
        useManualLimit = current.manualWeeklyLimit != nil
        manualLimitText = current.manualWeeklyLimit.map { String(format: "%.2f", $0) } ?? ""
        weekStartsMonday = current.weekStartsMonday
    }

    private func save() {
        let current = settings
        current.monthlyIncome = Double(monthlyIncomeText) ?? 0
        current.savingsGoalAmount = Double(savingsGoalText) ?? 0
        current.savingsGoalFrequency = savingsGoalFrequency.rawValue
        current.payFrequency = payFrequency.rawValue
        current.manualWeeklyLimit = useManualLimit ? (Double(manualLimitText) ?? 0) : nil
        current.weekStartsMonday = weekStartsMonday
        NotificationManager.shared.scheduleWeeklyResetReminder(weekStartsMonday: weekStartsMonday)
    }
}

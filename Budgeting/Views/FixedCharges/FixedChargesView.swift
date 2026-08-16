import SwiftUI
import SwiftData

struct FixedChargesView: View {
    @Environment(\.modelContext) private var context
    @Query private var charges: [RecurringCharge]
    @State private var isPresentingNew = false

    private var monthlyTotal: Double {
        BudgetEngine.totalMonthlyFixedCharges(charges)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total Fixed Charges")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(monthlyTotal.formattedCurrency + " / mo")
                            .fontWeight(.semibold)
                    }
                }

                Section("Recurring") {
                    ForEach(charges) { charge in
                        NavigationLink {
                            AddEditRecurringChargeView(charge: charge)
                        } label: {
                            RecurringChargeRow(charge: charge)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(charges[index]) }
                    }
                }
            }
            .overlay {
                if charges.isEmpty {
                    ContentUnavailableView("No Fixed Charges", systemImage: "repeat", description: Text("Add subscriptions, rent, insurance, and other recurring bills."))
                }
            }
            .navigationTitle("Fixed Charges")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isPresentingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isPresentingNew) {
                NavigationStack { AddEditRecurringChargeView(charge: nil) }
            }
        }
    }
}

private struct RecurringChargeRow: View {
    let charge: RecurringCharge

    var body: some View {
        HStack {
            Image(systemName: charge.category.systemImage)
                .frame(width: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text(charge.name)
                Text("\(charge.frequency.rawValue) · \(charge.category.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(charge.amount.formattedCurrency)
                if !charge.isActive {
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var isPresentingNew = false

    private var groupedByDay: [(Date, [Transaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return groups.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByDay, id: \.0) { day, dayTransactions in
                    Section(day.formatted(date: .abbreviated, time: .omitted)) {
                        ForEach(dayTransactions) { transaction in
                            NavigationLink {
                                AddEditTransactionView(transaction: transaction)
                            } label: {
                                TransactionRowView(transaction: transaction)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(dayTransactions[index]) }
                        }
                    }
                }
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView("No Spending Yet", systemImage: "list.bullet.rectangle", description: Text("Tap + to log your first transaction."))
                }
            }
            .navigationTitle("Spending")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isPresentingNew = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isPresentingNew) {
                NavigationStack { AddEditTransactionView(transaction: nil) }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var recurringCharges: [RecurringCharge]
    @Query private var settingsList: [BudgetSettings]

    private var settings: BudgetSettings { settingsList.first ?? BudgetSettings() }

    private var status: BudgetEngine.WeeklyStatus {
        BudgetEngine.weeklyStatus(settings: settings, fixedCharges: recurringCharges, transactions: transactions)
    }

    private var netWorth: Double {
        accounts.reduce(0) { sum, account in
            account.type == .creditCard ? sum - account.balance : sum + account.balance
        }
    }

    private var thisWeeksTransactions: [Transaction] {
        transactions.filter {
            $0.isDiscretionary && $0.kind == .expense && $0.date >= status.week.start && $0.date < status.week.end
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeeklyProgressCard(status: status)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Net Worth") {
                    HStack {
                        Text("Total across all accounts")
                        Spacer()
                        Text(netWorth.formattedCurrency)
                            .fontWeight(.semibold)
                            .foregroundStyle(netWorth >= 0 ? .primary : .red)
                    }
                }

                Section("Accounts") {
                    ForEach(accounts.sorted(by: { $0.sortOrder < $1.sortOrder })) { account in
                        AccountRowView(account: account)
                    }
                }

                Section("This Week's Spending") {
                    if thisWeeksTransactions.isEmpty {
                        Text("No spending logged yet this week.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(thisWeeksTransactions.prefix(5)) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .onChange(of: transactions.count) {
                NotificationManager.shared.evaluateWeeklyStatus(status, settings: settings)
            }
        }
    }
}

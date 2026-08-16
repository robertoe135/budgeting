import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "gauge.with.dots.needle.50percent") }

            AccountsListView()
                .tabItem { Label("Accounts", systemImage: "building.columns") }

            TransactionsListView()
                .tabItem { Label("Spending", systemImage: "list.bullet.rectangle") }

            FixedChargesView()
                .tabItem { Label("Fixed Charges", systemImage: "repeat") }

            BudgetSettingsView()
                .tabItem { Label("Budget", systemImage: "target") }
        }
    }
}

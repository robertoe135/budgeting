import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var isPresentingNewAccount = false

    private var grouped: [(AccountType, [Account])] {
        Dictionary(grouping: accounts, by: { $0.type })
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value.sorted { $0.sortOrder < $1.sortOrder }) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { type, accountsInGroup in
                    Section(type.rawValue) {
                        ForEach(accountsInGroup) { account in
                            NavigationLink {
                                AccountEditView(account: account)
                            } label: {
                                AccountRowView(account: account)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(accountsInGroup[index]) }
                        }
                    }
                }
            }
            .overlay {
                if accounts.isEmpty {
                    ContentUnavailableView("No Accounts", systemImage: "building.columns", description: Text("Tap + to add a checking, savings, or credit card account."))
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { isPresentingNewAccount = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $isPresentingNewAccount) {
                NavigationStack { AccountEditView(account: nil) }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct BankConnectionsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var backendConfig: BackendConfig
    @EnvironmentObject private var syncService: PlaidSyncService

    @State private var items: [PlaidItemSummary] = []
    @State private var isLoadingItems = false
    @State private var loadError: String?

    var body: some View {
        Form {
            Section("Backend") {
                TextField("https://your-app.up.railway.app", text: $backendConfig.baseURLString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API key", text: $backendConfig.apiKey)
                Text("Set these up once — see Backend/README.md for how to deploy the server and generate an API key. Nothing here ever touches your bank credentials directly; that only happens inside Plaid's own Link screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if backendConfig.isConfigured {
                Section("Linked Institutions") {
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if isLoadingItems {
                        ProgressView()
                    } else if items.isEmpty {
                        Text("No banks linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            LinkedItemRow(item: item) {
                                await unlink(item)
                            }
                        }
                    }
                    LinkBankAccountView(label: "Link a New Bank Account")
                }

                Section("Sync") {
                    if let lastSyncedAt = syncService.lastSyncedAt {
                        Text("Last synced \(lastSyncedAt.formatted(date: .abbreviated, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                    if let error = syncService.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Button {
                        Task {
                            try? await syncService.syncAll(context: context)
                            await loadItems()
                        }
                    } label: {
                        if syncService.isSyncing {
                            ProgressView()
                        } else {
                            Text("Sync Now")
                        }
                    }
                    .disabled(syncService.isSyncing)
                }
            }
        }
        .navigationTitle("Bank Connections")
        .task { await loadItems() }
        .onChange(of: backendConfig.isConfigured) { _, _ in
            Task { await loadItems() }
        }
    }

    private func loadItems() async {
        guard backendConfig.isConfigured else {
            items = []
            return
        }
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            items = try await PlaidAPIClient().fetchItems().items
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func unlink(_ item: PlaidItemSummary) async {
        do {
            try await PlaidAPIClient().unlinkItem(item.itemId)
            await loadItems()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct LinkedItemRow: View {
    let item: PlaidItemSummary
    let onUnlink: () async -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.institutionName ?? "Unknown Institution")
                if item.needsRelink {
                    Label("Needs re-link", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            if item.needsRelink {
                LinkBankAccountView(reauthorizingItemId: item.itemId, label: "Re-link")
                    .buttonStyle(.bordered)
            }
        }
        .swipeActions {
            Button("Unlink", role: .destructive) {
                Task { await onUnlink() }
            }
        }
    }
}

import SwiftUI
import SwiftData

@main
struct BudgetingApp: App {
    private let container = SharedModelContainer.shared
    @StateObject private var backendConfig = BackendConfig.shared
    @StateObject private var syncService = PlaidSyncService.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationManager.shared.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(backendConfig)
                .environmentObject(syncService)
                .onAppear(perform: bootstrap)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            syncIfConfigured()
        }
    }

    @MainActor
    private func bootstrap() {
        let context = container.mainContext
        SharedModelContainer.seedDefaultAccountsIfNeeded(in: context)
        let settings = SharedModelContainer.fetchOrCreateSettings(in: context)
        NotificationManager.shared.scheduleWeeklyResetReminder(weekStartsMonday: settings.weekStartsMonday)
        syncIfConfigured()
    }

    /// There's no push/webhook delivery to the app in v1 — this foreground-triggered pull is
    /// what keeps Plaid-linked accounts and transactions current. Cheap enough at personal
    /// scale to just do it every time the app becomes active.
    @MainActor
    private func syncIfConfigured() {
        guard backendConfig.isConfigured else { return }
        let context = container.mainContext
        Task {
            try? await syncService.syncAll(context: context)
        }
    }
}

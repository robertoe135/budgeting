import SwiftUI
import SwiftData

@main
struct BudgetingApp: App {
    private let container = SharedModelContainer.shared

    init() {
        NotificationManager.shared.requestAuthorizationIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .onAppear(perform: bootstrap)
        }
        .modelContainer(container)
    }

    @MainActor
    private func bootstrap() {
        let context = container.mainContext
        SharedModelContainer.seedDefaultAccountsIfNeeded(in: context)
        let settings = SharedModelContainer.fetchOrCreateSettings(in: context)
        NotificationManager.shared.scheduleWeeklyResetReminder(weekStartsMonday: settings.weekStartsMonday)
    }
}

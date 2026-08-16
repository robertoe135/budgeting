import Foundation
import SwiftData

/// The App Group shared between the main app and the widget extension so both can read/write
/// the same SwiftData store. Update this identifier (and the matching entries in
/// Budgeting.entitlements / BudgetingWidget.entitlements) if you change the bundle ID prefix.
enum AppGroup {
    static let identifier = "group.com.robertoesquenazi.budgeting"
}

enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Account.self, Transaction.self, RecurringCharge.self, BudgetSettings.self])

        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) else {
            fatalError("""
                Unable to resolve the app group container URL. Confirm the '\(AppGroup.identifier)' \
                App Group capability is enabled for both the Budgeting and BudgetingWidgetExtension targets.
                """)
        }

        let storeURL = groupURL.appendingPathComponent("Budgeting.sqlite")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create the shared ModelContainer: \(error)")
        }
    }()

    /// Fetches the single settings row, creating it if this is the first launch.
    @MainActor
    @discardableResult
    static func fetchOrCreateSettings(in context: ModelContext) -> BudgetSettings {
        if let existing = try? context.fetch(FetchDescriptor<BudgetSettings>()).first {
            return existing
        }
        let settings = BudgetSettings()
        context.insert(settings)
        return settings
    }

    /// Seeds the specific accounts requested for this tracker on first launch only.
    @MainActor
    static func seedDefaultAccountsIfNeeded(in context: ModelContext) {
        let existingCount = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        guard existingCount == 0 else { return }

        let defaults: [(name: String, institution: Institution, type: AccountType)] = [
            ("Chase Checking", .chase, .checking),
            ("Chase Savings", .chase, .savings),
            ("Amex Checking", .amex, .checking),
            ("Amex Savings", .amex, .savings),
            ("Amex Card", .amex, .creditCard),
            ("Apple Card", .apple, .creditCard),
            ("Chase Prime Visa", .chase, .creditCard)
        ]

        for (index, entry) in defaults.enumerated() {
            let account = Account(name: entry.name, institution: entry.institution, type: entry.type, sortOrder: index)
            context.insert(account)
        }
    }
}

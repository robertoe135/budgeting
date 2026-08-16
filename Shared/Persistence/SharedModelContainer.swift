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
        let configuration: ModelConfiguration

        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            let storeURL = groupURL.appendingPathComponent("Budgeting.sqlite")
            configuration = ModelConfiguration(schema: schema, url: storeURL)
        } else {
            // Falls back to the app's own local storage instead of crashing outright — a
            // misconfigured/not-yet-provisioned App Group (a common first-run signing gotcha)
            // would otherwise hard-crash the app at launch with no way to even see it run. The
            // trade-off: the widget can't read this data until the App Groups capability is
            // actually enabled for both the Budgeting and BudgetingWidgetExtension targets in
            // Xcode's Signing & Capabilities (see Backend/README.md's sibling, the root README,
            // "Opening the project" section).
            print("""
                ⚠️ Could not resolve the '\(AppGroup.identifier)' App Group container — falling \
                back to app-local storage. The app will work, but the home screen widget won't \
                show data until App Groups is enabled for both targets in Signing & Capabilities.
                """)
            configuration = ModelConfiguration(schema: schema)
        }

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

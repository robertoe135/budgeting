import Foundation
import SwiftData

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case weekly = "Weekly"
    case biWeekly = "Every 2 Weeks"
    case annually = "Annually"

    var id: String { rawValue }

    /// Approximate monthly cost used for budget math.
    func monthlyEquivalent(of amount: Double) -> Double {
        switch self {
        case .monthly: return amount
        case .weekly: return amount * 52 / 12
        case .biWeekly: return amount * 26 / 12
        case .annually: return amount / 12
        }
    }
}

/// A fixed, recurring monthly outgoing charge: rent, subscriptions, insurance, utilities, etc.
@Model
final class RecurringCharge {
    var id: UUID
    var name: String
    var amount: Double
    var categoryRaw: String
    var frequencyRaw: String
    /// Day of month (1-31) the charge is due, used for display/reminders.
    var dayOfMonth: Int
    var isActive: Bool
    var account: Account?

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .subscriptions }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var monthlyAmount: Double { frequency.monthlyEquivalent(of: amount) }

    init(
        name: String,
        amount: Double,
        category: TransactionCategory = .subscriptions,
        frequency: RecurringFrequency = .monthly,
        dayOfMonth: Int = 1,
        isActive: Bool = true,
        account: Account? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.frequencyRaw = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.account = account
    }
}

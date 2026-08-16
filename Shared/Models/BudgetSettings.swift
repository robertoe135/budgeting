import Foundation
import SwiftData

enum SavingsGoalFrequency: String, Codable, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case perPaycheck = "Per Paycheck"

    var id: String { rawValue }
}

enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case biWeekly = "Every 2 Weeks"
    case semiMonthly = "Twice a Month"
    case monthly = "Monthly"

    var id: String { rawValue }

    /// Average number of paychecks per month, used to convert a per-paycheck savings goal
    /// into a monthly figure.
    var paychecksPerMonth: Double {
        switch self {
        case .weekly: return 52.0 / 12.0
        case .biWeekly: return 26.0 / 12.0
        case .semiMonthly: return 2
        case .monthly: return 1
        }
    }
}

/// Single-row app configuration: income, savings goal, and weekly budget preferences.
/// `SharedModelContainer.fetchOrCreateSettings(in:)` guarantees exactly one row exists.
@Model
final class BudgetSettings {
    var id: UUID
    var monthlyIncome: Double
    var savingsGoalAmount: Double
    var savingsGoalFrequency: String
    var payFrequency: String
    var weekStartsMonday: Bool
    /// When set, overrides the auto-computed (income - fixed charges - savings) / weeks limit.
    var manualWeeklyLimit: Double?
    var notifyAt80Percent: Bool
    var notifyAtOverLimit: Bool
    var notificationsEnabled: Bool

    init(
        monthlyIncome: Double = 0,
        savingsGoalAmount: Double = 0,
        savingsGoalFrequency: SavingsGoalFrequency = .monthly,
        payFrequency: PayFrequency = .monthly,
        weekStartsMonday: Bool = true,
        manualWeeklyLimit: Double? = nil,
        notifyAt80Percent: Bool = true,
        notifyAtOverLimit: Bool = true,
        notificationsEnabled: Bool = true
    ) {
        self.id = UUID()
        self.monthlyIncome = monthlyIncome
        self.savingsGoalAmount = savingsGoalAmount
        self.savingsGoalFrequency = savingsGoalFrequency.rawValue
        self.payFrequency = payFrequency.rawValue
        self.weekStartsMonday = weekStartsMonday
        self.manualWeeklyLimit = manualWeeklyLimit
        self.notifyAt80Percent = notifyAt80Percent
        self.notifyAtOverLimit = notifyAtOverLimit
        self.notificationsEnabled = notificationsEnabled
    }
}

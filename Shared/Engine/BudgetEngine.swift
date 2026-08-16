import Foundation

/// Pure, testable budget math shared by the app and the widget extension.
enum BudgetEngine {

    struct WeekInterval: Equatable {
        let start: Date
        /// Exclusive end (start of the following week).
        let end: Date
    }

    struct WeeklyStatus {
        let week: WeekInterval
        let limit: Double
        let spent: Double

        var remaining: Double { limit - spent }
        var percentUsed: Double { limit > 0 ? spent / limit : 0 }
        var isOverLimit: Bool { spent > limit }
    }

    static func weekInterval(containing date: Date, weekStartsMonday: Bool, calendar: Calendar = .current) -> WeekInterval {
        var cal = calendar
        cal.firstWeekday = weekStartsMonday ? 2 : 1
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? date
        return WeekInterval(start: start, end: end)
    }

    static func weeksInMonth(containing date: Date, weekStartsMonday: Bool, calendar: Calendar = .current) -> Int {
        var cal = calendar
        cal.firstWeekday = weekStartsMonday ? 2 : 1
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return 4 }
        let days = cal.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        return max(Int((Double(days) / 7.0).rounded()), 1)
    }

    static func totalMonthlyFixedCharges(_ charges: [RecurringCharge]) -> Double {
        charges.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyAmount }
    }

    static func monthlySavingsGoal(settings: BudgetSettings) -> Double {
        let frequency = SavingsGoalFrequency(rawValue: settings.savingsGoalFrequency) ?? .monthly
        switch frequency {
        case .monthly:
            return settings.savingsGoalAmount
        case .perPaycheck:
            let payFrequency = PayFrequency(rawValue: settings.payFrequency) ?? .monthly
            return settings.savingsGoalAmount * payFrequency.paychecksPerMonth
        }
    }

    /// (income - fixed charges - savings goal) split evenly across the weeks in the reference month.
    static func suggestedWeeklyLimit(settings: BudgetSettings, fixedCharges: [RecurringCharge], referenceDate: Date = .now) -> Double {
        let discretionaryMonthly = settings.monthlyIncome - totalMonthlyFixedCharges(fixedCharges) - monthlySavingsGoal(settings: settings)
        let weeks = weeksInMonth(containing: referenceDate, weekStartsMonday: settings.weekStartsMonday)
        return max(discretionaryMonthly / Double(weeks), 0)
    }

    /// The manual override if the user set one, otherwise the auto-suggested weekly limit.
    static func effectiveWeeklyLimit(settings: BudgetSettings, fixedCharges: [RecurringCharge], referenceDate: Date = .now) -> Double {
        settings.manualWeeklyLimit ?? suggestedWeeklyLimit(settings: settings, fixedCharges: fixedCharges, referenceDate: referenceDate)
    }

    static func discretionarySpent(transactions: [Transaction], in week: WeekInterval) -> Double {
        transactions
            .filter { $0.isDiscretionary && $0.kind == .expense && $0.date >= week.start && $0.date < week.end }
            .reduce(0) { $0 + $1.amount }
    }

    static func weeklyStatus(settings: BudgetSettings, fixedCharges: [RecurringCharge], transactions: [Transaction], referenceDate: Date = .now) -> WeeklyStatus {
        let week = weekInterval(containing: referenceDate, weekStartsMonday: settings.weekStartsMonday)
        let limit = effectiveWeeklyLimit(settings: settings, fixedCharges: fixedCharges, referenceDate: referenceDate)
        let spent = discretionarySpent(transactions: transactions, in: week)
        return WeeklyStatus(week: week, limit: limit, spent: spent)
    }
}

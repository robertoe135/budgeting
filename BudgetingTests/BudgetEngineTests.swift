import XCTest
import SwiftData

final class BudgetEngineTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Account.self, Transaction.self, RecurringCharge.self, BudgetSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    private var referenceDate: Date {
        DateComponents(calendar: .current, year: 2026, month: 8, day: 16).date!
    }

    func testSuggestedWeeklyLimitSplitsDiscretionaryIncomeAcrossWeeks() {
        let settings = BudgetSettings(monthlyIncome: 4000, savingsGoalAmount: 500, savingsGoalFrequency: .monthly, payFrequency: .monthly)
        let rent = RecurringCharge(name: "Rent", amount: 1500, category: .housing, frequency: .monthly)
        let netflix = RecurringCharge(name: "Netflix", amount: 15, category: .subscriptions, frequency: .monthly)
        context.insert(settings)
        context.insert(rent)
        context.insert(netflix)

        let weekly = BudgetEngine.suggestedWeeklyLimit(settings: settings, fixedCharges: [rent, netflix], referenceDate: referenceDate)

        // Discretionary monthly = 4000 - (1500 + 15) - 500 = 1985, split across the weeks in August 2026.
        let weeks = BudgetEngine.weeksInMonth(containing: referenceDate, weekStartsMonday: settings.weekStartsMonday)
        XCTAssertEqual(weekly, 1985.0 / Double(weeks), accuracy: 0.01)
    }

    func testManualWeeklyLimitOverridesSuggestion() {
        let settings = BudgetSettings(monthlyIncome: 4000, savingsGoalAmount: 0, manualWeeklyLimit: 100)
        context.insert(settings)

        let limit = BudgetEngine.effectiveWeeklyLimit(settings: settings, fixedCharges: [])
        XCTAssertEqual(limit, 100)
    }

    func testWeeklyStatusFlagsOverLimit() {
        let settings = BudgetSettings(manualWeeklyLimit: 100)
        let account = Account(name: "Chase Checking", institution: .chase, type: .checking)
        context.insert(settings)
        context.insert(account)

        let tx1 = Transaction(date: referenceDate, amount: 60, merchant: "Groceries", category: .groceries, account: account)
        let tx2 = Transaction(date: referenceDate, amount: 50, merchant: "Dinner", category: .diningOut, account: account)
        context.insert(tx1)
        context.insert(tx2)

        let status = BudgetEngine.weeklyStatus(settings: settings, fixedCharges: [], transactions: [tx1, tx2], referenceDate: referenceDate)
        XCTAssertEqual(status.spent, 110)
        XCTAssertTrue(status.isOverLimit)
    }

    func testFixedCategoryTransactionsAreExcludedFromDiscretionarySpend() {
        let settings = BudgetSettings(manualWeeklyLimit: 100)
        context.insert(settings)

        let rentPayment = Transaction(date: referenceDate, amount: 1500, merchant: "Landlord", category: .housing)
        context.insert(rentPayment)

        let status = BudgetEngine.weeklyStatus(settings: settings, fixedCharges: [], transactions: [rentPayment], referenceDate: referenceDate)
        XCTAssertEqual(status.spent, 0)
        XCTAssertFalse(status.isOverLimit)
    }

    func testPerPaycheckSavingsGoalConvertsToMonthlyEquivalent() {
        let settings = BudgetSettings(savingsGoalAmount: 100, savingsGoalFrequency: .perPaycheck, payFrequency: .weekly)
        context.insert(settings)

        let monthly = BudgetEngine.monthlySavingsGoal(settings: settings)
        XCTAssertEqual(monthly, 100 * (52.0 / 12.0), accuracy: 0.01)
    }
}

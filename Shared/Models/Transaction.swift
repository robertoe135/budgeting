import Foundation
import SwiftData

/// Spending/income categories. Categories in `fixedCategories` are treated as fixed monthly
/// outgoings (rent, insurance, subscriptions, utilities) rather than discretionary weekly spend.
enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case groceries = "Groceries"
    case diningOut = "Dining Out"
    case transportation = "Transportation"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case health = "Health"
    case travel = "Travel"
    case housing = "Housing"
    case utilities = "Utilities"
    case subscriptions = "Subscriptions"
    case insurance = "Insurance"
    case income = "Income"
    case transfer = "Transfer"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .groceries: return "cart"
        case .diningOut: return "fork.knife"
        case .transportation: return "car"
        case .shopping: return "bag"
        case .entertainment: return "film"
        case .health: return "heart"
        case .travel: return "airplane"
        case .housing: return "house"
        case .utilities: return "bolt"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .insurance: return "shield"
        case .income: return "arrow.down.circle"
        case .transfer: return "arrow.left.arrow.right"
        case .other: return "questionmark.circle"
        }
    }

    /// Categories that represent fixed monthly outflows rather than discretionary weekly spend.
    static let fixedCategories: Set<TransactionCategory> = [.housing, .utilities, .subscriptions, .insurance]
}

enum TransactionKind: String, Codable {
    case expense
    case income
}

/// A single expense or income entry — either typed in manually, or synced down from Plaid.
@Model
final class Transaction {
    var id: UUID
    var date: Date
    /// Always stored as a positive number; `kind` determines the sign for balance math.
    var amount: Double
    var merchant: String
    var notes: String
    var categoryRaw: String
    var kindRaw: String
    /// Whether this entry counts against the weekly spending limit. Defaults based on category,
    /// but can be overridden (e.g. a one-off large "shopping" purchase you don't want counted).
    var isDiscretionary: Bool
    var account: Account?
    var recurringCharge: RecurringCharge?

    /// Non-nil for transactions synced from Plaid; used to upsert/de-dupe on sync and to tell a
    /// Plaid-sourced entry apart from one the user typed in by hand. Nil for manual entries.
    var plaidTransactionId: String?
    /// Mirrors Plaid's `pending` flag — the charge has authorized but not yet posted, so the
    /// amount/category may still change on a later sync.
    var isPending: Bool

    var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        amount: Double,
        merchant: String,
        notes: String = "",
        category: TransactionCategory = .other,
        kind: TransactionKind = .expense,
        isDiscretionary: Bool? = nil,
        account: Account? = nil,
        recurringCharge: RecurringCharge? = nil,
        plaidTransactionId: String? = nil,
        isPending: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.kindRaw = kind.rawValue
        self.isDiscretionary = isDiscretionary ?? !TransactionCategory.fixedCategories.contains(category)
        self.account = account
        self.recurringCharge = recurringCharge
        self.plaidTransactionId = plaidTransactionId
        self.isPending = isPending
    }
}

import Foundation
import SwiftData

/// The financial institution an account is held at.
enum Institution: String, Codable, CaseIterable, Identifiable {
    case chase = "Chase"
    case amex = "American Express"
    case apple = "Apple"
    case other = "Other"

    var id: String { rawValue }
}

/// The kind of account, which drives how its balance is interpreted.
enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking = "Checking"
    case savings = "Savings"
    case creditCard = "Credit Card"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .checking: return "banknote"
        case .savings: return "building.columns"
        case .creditCard: return "creditcard"
        }
    }
}

/// A tracked bank or credit account. Balances are entered/maintained manually by the user
/// (this app does not link to banks) and are nudged automatically as transactions are logged.
@Model
final class Account {
    var id: UUID
    var name: String
    var institutionRaw: String
    var typeRaw: String
    /// For checking/savings this is the current balance. For credit cards this is the current
    /// balance owed, stored as a positive number.
    var balance: Double
    /// Only meaningful for credit cards.
    var creditLimit: Double?
    var colorHex: String
    var sortOrder: Int
    var isArchived: Bool

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringCharge.account)
    var recurringCharges: [RecurringCharge]? = []

    var institution: Institution {
        get { Institution(rawValue: institutionRaw) ?? .other }
        set { institutionRaw = newValue.rawValue }
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .checking }
        set { typeRaw = newValue.rawValue }
    }

    init(
        name: String,
        institution: Institution,
        type: AccountType,
        balance: Double = 0,
        creditLimit: Double? = nil,
        colorHex: String = "0A84FF",
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.institutionRaw = institution.rawValue
        self.typeRaw = type.rawValue
        self.balance = balance
        self.creditLimit = creditLimit
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isArchived = isArchived
    }

    var availableCredit: Double? {
        guard type == .creditCard, let limit = creditLimit else { return nil }
        return max(limit - balance, 0)
    }
}

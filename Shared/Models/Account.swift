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

/// A tracked bank or credit account. Balances are either entered/maintained manually (nudged
/// automatically as transactions are logged) or, for Plaid-linked accounts, synced straight
/// from Plaid — see `plaidAccountId`.
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

    /// Non-nil once this account is linked via Plaid. `plaidItemId` identifies the institution
    /// login (an Item can have multiple accounts); `plaidAccountId` identifies this specific
    /// account within that Item. Both nil means the account is manually tracked.
    var plaidAccountId: String?
    var plaidItemId: String?

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
        isArchived: Bool = false,
        plaidAccountId: String? = nil,
        plaidItemId: String? = nil
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
        self.plaidAccountId = plaidAccountId
        self.plaidItemId = plaidItemId
    }

    var isPlaidLinked: Bool { plaidAccountId != nil }

    var availableCredit: Double? {
        guard type == .creditCard, let limit = creditLimit else { return nil }
        return max(limit - balance, 0)
    }
}

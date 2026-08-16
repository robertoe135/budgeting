import Foundation

// Maps Plaid's vocabulary onto this app's models. These are heuristics, not an exhaustive
// lookup table — Plaid's institution names and category taxonomy aren't a closed enum on the
// client side, so everything here degrades gracefully (falls back to `.other`/`.checking`/nil)
// rather than crashing on an unrecognized value. Worth spot-checking against real linked
// accounts once you're testing against production Plaid data, since some of this (particularly
// the detailed Personal Finance Category prefixes) is written from documentation/memory rather
// than a live Plaid response.

extension Institution {
    static func from(plaidInstitutionName: String?) -> Institution {
        guard let name = plaidInstitutionName?.lowercased() else { return .other }
        if name.contains("chase") { return .chase }
        if name.contains("amex") || name.contains("american express") { return .amex }
        if name.contains("apple") { return .apple }
        return .other
    }
}

extension AccountType {
    /// `type`/`subtype` are Plaid's account type taxonomy, e.g. type "depository" with
    /// subtype "checking"/"savings", or type "credit" for any credit card.
    static func from(plaidType: String, subtype: String?) -> AccountType {
        switch plaidType {
        case "credit":
            return .creditCard
        case "depository":
            return subtype == "savings" ? .savings : .checking
        default:
            return .checking
        }
    }
}

extension TransactionCategory {
    /// Maps a Plaid Personal Finance Category value (preferably the granular "detailed" one,
    /// e.g. "FOOD_AND_DRINK_GROCERIES"; "primary" alone, e.g. "FOOD_AND_DRINK", also works but
    /// less precisely) onto this app's categories. Returns nil for anything unrecognized —
    /// callers should treat nil as "leave the existing/default category alone" rather than
    /// forcing a guess.
    static func from(plaidCategory: String?) -> TransactionCategory? {
        guard let raw = plaidCategory?.uppercased() else { return nil }

        if raw.hasPrefix("FOOD_AND_DRINK") {
            return raw.contains("GROCER") ? .groceries : .diningOut
        }
        if raw.hasPrefix("TRANSPORTATION") { return .transportation }
        if raw.hasPrefix("TRAVEL") { return .travel }
        if raw.hasPrefix("GENERAL_MERCHANDISE") { return .shopping }
        if raw.hasPrefix("ENTERTAINMENT") { return .entertainment }
        if raw.hasPrefix("PERSONAL_CARE") || raw.hasPrefix("MEDICAL") { return .health }
        if raw.hasPrefix("RENT_AND_UTILITIES") {
            return (raw.contains("RENT") || raw.contains("MORTGAGE")) ? .housing : .utilities
        }
        if raw.hasPrefix("GENERAL_SERVICES"), raw.contains("INSURANCE") { return .insurance }
        if raw.hasPrefix("INCOME") { return .income }
        if raw.hasPrefix("TRANSFER") { return .transfer }
        // HOME_IMPROVEMENT, LOAN_PAYMENTS, BANK_FEES, other GENERAL_SERVICES,
        // GOVERNMENT_AND_NON_PROFIT, and anything unrecognized: no confident mapping.
        return nil
    }
}

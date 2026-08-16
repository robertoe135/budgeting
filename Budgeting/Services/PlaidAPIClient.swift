import Foundation

// MARK: - DTOs (mirror Backend/src/routes/*.js response shapes exactly)

struct LinkTokenResponse: Decodable {
    let linkToken: String
    let expiration: String
}

struct ExchangeTokenResponse: Decodable {
    let itemId: String
    let institutionName: String?
}

struct PlaidItemSummary: Decodable, Identifiable {
    let itemId: String
    let institutionId: String?
    let institutionName: String?
    /// "active" | "login_required"
    let status: String
    let createdAt: String

    var id: String { itemId }
    var needsRelink: Bool { status != "active" }
}

struct ItemsResponse: Decodable {
    let items: [PlaidItemSummary]
}

struct PlaidBalances: Decodable {
    let available: Double?
    let current: Double?
    let limit: Double?
    let isoCurrencyCode: String?
}

struct PlaidAccountDTO: Decodable {
    let itemId: String
    let institutionName: String?
    let accountId: String
    let name: String
    let officialName: String?
    let mask: String?
    let type: String
    let subtype: String?
    let balances: PlaidBalances
}

struct ItemErrorDTO: Decodable {
    let itemId: String
    let institutionName: String?
    let errorCode: String
}

struct AccountsResponse: Decodable {
    let accounts: [PlaidAccountDTO]
    let itemErrors: [ItemErrorDTO]
}

struct PlaidTransactionDTO: Decodable {
    let itemId: String
    let accountId: String
    let transactionId: String
    let amount: Double
    /// "expense" | "income" — already sign-normalized server-side.
    let kind: String
    let isoCurrencyCode: String?
    /// "YYYY-MM-DD"
    let date: String
    let merchantName: String
    let pending: Bool
    let category: String?
}

struct RemovedTransactionDTO: Decodable {
    let itemId: String
    let transactionId: String
}

struct TransactionsSyncResponse: Decodable {
    let added: [PlaidTransactionDTO]
    let modified: [PlaidTransactionDTO]
    let removed: [RemovedTransactionDTO]
    let itemErrors: [ItemErrorDTO]
}

// MARK: - Client

enum PlaidAPIError: LocalizedError {
    case notConfigured
    case http(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Backend URL and API key aren't configured yet. Add them in Accounts \u{2192} Bank Connections."
        case .http(let status, let message):
            return message ?? "Backend request failed (HTTP \(status))."
        case .decoding:
            return "The backend returned an unexpected response."
        case .transport(let error):
            return error.localizedDescription
        }
    }
}

/// Talks to *our own* backend (see Backend/), never to Plaid directly — the app never sees a
/// Plaid access token, only the ephemeral link token and public token involved in the Link flow.
struct PlaidAPIClient {
    private let config: BackendConfig

    init(config: BackendConfig = .shared) {
        self.config = config
    }

    func fetchLinkToken(reauthorizingItemId: String? = nil) async throws -> LinkTokenResponse {
        var body: [String: String] = [:]
        if let reauthorizingItemId { body["itemId"] = reauthorizingItemId }
        return try await request("POST", "/link/token", body: body)
    }

    func exchangePublicToken(_ publicToken: String, institutionId: String?, institutionName: String?) async throws -> ExchangeTokenResponse {
        var body: [String: Any] = ["publicToken": publicToken]
        if let institutionId { body["institutionId"] = institutionId }
        if let institutionName { body["institutionName"] = institutionName }
        return try await request("POST", "/link/exchange", body: body)
    }

    func fetchItems() async throws -> ItemsResponse {
        try await request("GET", "/items")
    }

    func unlinkItem(_ itemId: String) async throws {
        try await requestNoContent("DELETE", "/items/\(itemId)")
    }

    func fetchAccounts() async throws -> AccountsResponse {
        try await request("GET", "/accounts")
    }

    func syncTransactions() async throws -> TransactionsSyncResponse {
        try await request("GET", "/transactions/sync")
    }

    // MARK: - Plumbing

    private func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> T {
        let (data, _) = try await rawRequest(method, path, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PlaidAPIError.decoding(error)
        }
    }

    private func requestNoContent(_ method: String, _ path: String) async throws {
        _ = try await rawRequest(method, path, body: nil)
    }

    private func rawRequest(_ method: String, _ path: String, body: [String: Any]?) async throws -> (Data, URLResponse) {
        guard let baseURL = config.baseURL, !config.apiKey.isEmpty else {
            throw PlaidAPIError.notConfigured
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PlaidAPIError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaidAPIError.http(status: 0, message: nil)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw PlaidAPIError.http(status: httpResponse.statusCode, message: message)
        }
        return (data, response)
    }
}

import Foundation
import Combine

/// Where the app's own backend lives and how to authenticate to it. The backend URL isn't
/// secret (it's just a hostname), so it lives in UserDefaults; the API key is a real credential
/// and lives in the Keychain. See Backend/README.md for how to stand the server up.
@MainActor
final class BackendConfig: ObservableObject {
    static let shared = BackendConfig()

    private static let baseURLDefaultsKey = "backendBaseURL"
    private static let apiKeyKeychainKey = "backendAPIKey"

    @Published var baseURLString: String {
        didSet { UserDefaults.standard.set(baseURLString, forKey: Self.baseURLDefaultsKey) }
    }

    @Published var apiKey: String {
        didSet { KeychainStore.set(apiKey, for: Self.apiKeyKeychainKey) }
    }

    private init() {
        self.baseURLString = UserDefaults.standard.string(forKey: Self.baseURLDefaultsKey) ?? ""
        self.apiKey = KeychainStore.get(Self.apiKeyKeychainKey) ?? ""
    }

    var baseURL: URL? {
        guard !baseURLString.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: baseURLString)
    }

    var isConfigured: Bool {
        baseURL != nil && !apiKey.isEmpty
    }
}

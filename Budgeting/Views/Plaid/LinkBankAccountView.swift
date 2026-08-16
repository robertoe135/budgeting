import SwiftUI
import SwiftData
import LinkKit

/// A button that fetches a link token from our backend and presents Plaid Link. Pass
/// `reauthorizingItemId` to re-link an already-linked institution in Plaid's "update mode"
/// (used after an item goes into `login_required`); leave it nil to link a new institution.
///
/// `success.metadata.institution` is non-optional in LinkKit 7.x's `SuccessMetadata` (confirmed
/// via a real build — Xcode flagged the `?` this file originally had as invalid optional
/// chaining on a non-optional value).
struct LinkBankAccountView: View {
    // Qualified because LinkKit also exports a type named `Environment` (its Plaid
    // sandbox/development/production enum), which otherwise collides with SwiftUI's.
    @SwiftUI.Environment(\.modelContext) private var context
    @EnvironmentObject private var syncService: PlaidSyncService

    var reauthorizingItemId: String? = nil
    var label: String = "Link a Bank Account"

    @State private var linkToken: String?
    @State private var isPresentingLink = false
    @State private var isFetchingToken = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            fetchTokenAndPresent()
        } label: {
            if isFetchingToken {
                ProgressView()
            } else {
                Label(label, systemImage: "link")
            }
        }
        .disabled(isFetchingToken)
        .alert("Couldn't Start Link", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $isPresentingLink) {
            if let linkToken {
                PlaidLinkView(token: linkToken) { success in
                    isPresentingLink = false
                    Task {
                        await syncService.completeLink(
                            publicToken: success.publicToken,
                            institutionId: success.metadata.institution.id,
                            institutionName: success.metadata.institution.name,
                            context: context
                        )
                    }
                } onExit: { exit in
                    isPresentingLink = false
                    if let error = exit.error {
                        errorMessage = error.localizedDescription
                    }
                } onEvent: { _ in
                    // Available for diagnostics/analytics later; nothing to do with it yet.
                } errorView: { error in
                    VStack(spacing: 12) {
                        Text("Failed to load Plaid Link")
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Dismiss") { isPresentingLink = false }
                    }
                    .padding()
                }
            }
        }
    }

    private func fetchTokenAndPresent() {
        isFetchingToken = true
        Task {
            defer { isFetchingToken = false }
            do {
                let response = try await PlaidAPIClient().fetchLinkToken(reauthorizingItemId: reauthorizingItemId)
                linkToken = response.linkToken
                isPresentingLink = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

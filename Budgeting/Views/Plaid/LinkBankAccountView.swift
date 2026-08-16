import SwiftUI
import SwiftData
import LinkKit

/// A button that fetches a link token from our backend and presents Plaid Link. Pass
/// `reauthorizingItemId` to re-link an already-linked institution in Plaid's "update mode"
/// (used after an item goes into `login_required`); leave it nil to link a new institution.
///
/// Uses the session-based `Plaid.createPlaidLinkSession` API rather than the simpler
/// `PlaidLinkView` — the latter is deprecated in current LinkKit in favor of this one.
struct LinkBankAccountView: View {
    // Qualified because LinkKit also exports a type named `Environment` (its Plaid
    // sandbox/development/production enum), which otherwise collides with SwiftUI's.
    @SwiftUI.Environment(\.modelContext) private var context
    @EnvironmentObject private var syncService: PlaidSyncService

    var reauthorizingItemId: String? = nil
    var label: String = "Link a Bank Account"

    @State private var linkSession: PlaidLinkSession?
    @State private var isPresentingLink = false
    @State private var isFetchingToken = false
    @State private var errorMessage: String?

    var body: some View {
        Button {
            fetchTokenAndCreateSession()
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
            if let linkSession {
                linkSession.sheet()
            }
        }
    }

    private func fetchTokenAndCreateSession() {
        isFetchingToken = true
        Task {
            defer { isFetchingToken = false }
            do {
                let response = try await PlaidAPIClient().fetchLinkToken(reauthorizingItemId: reauthorizingItemId)
                createSession(linkToken: response.linkToken)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createSession(linkToken: String) {
        let configuration = LinkTokenConfiguration(
            token: linkToken,
            onSuccess: { success in
                isPresentingLink = false
                Task {
                    await syncService.completeLink(
                        publicToken: success.publicToken,
                        institutionId: success.metadata.institution.id,
                        institutionName: success.metadata.institution.name,
                        context: context
                    )
                }
            },
            onExit: { exit in
                isPresentingLink = false
                if let error = exit.error {
                    errorMessage = error.localizedDescription
                }
            },
            onEvent: { _ in
                // Available for diagnostics/analytics later; nothing to do with it yet.
            },
            onLoad: {
                // Link's own UI is ready inside the sheet; nothing extra needed here since we
                // don't gate presenting the sheet on this (unlike Plaid's own sample, which
                // waits for onLoad before enabling its button) — the sheet shows Link's own
                // loading state until this fires.
            }
        )

        do {
            linkSession = try Plaid.createPlaidLinkSession(configuration: configuration)
            isPresentingLink = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

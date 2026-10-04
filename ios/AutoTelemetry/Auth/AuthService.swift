import ClerkKit
import Foundation
import Observation

enum AuthState: Equatable {
    case loading
    case signedOut
    /// Using the app without an account: everything stays on this phone, nothing streams.
    case guest
    case signedIn(userId: String, email: String?)
}

/// Identity for the whole app. Signing in is Clerk, the same identity the router verifies, so the same person
/// lands on the same backend instance as on Android and the web. A guest has no token and never uploads.
@MainActor @Observable
final class AuthService {
    private(set) var isGuest = UserDefaults.standard.bool(forKey: "guest")
    /// Clerk couldn't finish starting (offline first launch): show the sign-in screen rather than a blank one.
    private var loadTimedOut = false

    init() {
        Clerk.configure(publishableKey: Config.clerkPublishableKey)
        Task {
            try? await Task.sleep(for: .seconds(8))
            loadTimedOut = true
        }
    }

    var state: AuthState {
        if let user = Clerk.shared.user {
            return .signedIn(userId: user.id, email: user.primaryEmailAddress?.emailAddress)
        }
        if isGuest { return .guest }
        return Clerk.shared.isLoaded || loadTimedOut ? .signedOut : .loading
    }

    /// Owner id for stored data: the account id, or the guest id; nil until we know.
    var ownerId: String? {
        switch state {
        case .signedIn(let id, _): id
        case .guest: guestOwnerId
        default: nil
        }
    }

    func continueAsGuest() { setGuest(true) }

    /// Opens Google sign-in (Clerk OAuth). Returns an error message to show, or nil on success.
    func signInWithGoogle() async -> String? {
        do {
            try await Clerk.shared.auth.signInWithOAuth(provider: .google)
            setGuest(false)
            return nil
        } catch {
            if (error as? CancellationError) != nil { return nil }
            return "Couldn't sign in with Google. Check your connection and try again."
        }
    }

    func signOut() async {
        setGuest(false)
        try? await Clerk.shared.auth.signOut()
    }

    /// A session token for the router, or nil when not signed in or offline. [skipCache] forces a fresh one.
    func token(skipCache: Bool = false) async -> String? {
        guard Clerk.shared.session != nil else { return nil }
        return try? await Clerk.shared.auth.getToken(.init(skipCache: skipCache))
    }

    private func setGuest(_ value: Bool) {
        isGuest = value
        UserDefaults.standard.set(value, forKey: "guest")
    }
}

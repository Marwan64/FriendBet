import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var isAuthenticated = false
    @Published var currentUserID: String?
    @Published var displayName: String = UserDefaults.standard.string(forKey: "friendbet.displayName") ?? ""
    @Published var authError: String?
    @Published var isBusy = false
    @Published var firebaseReady = FirebaseBootstrap.hasConfigurationFile

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private(set) var pendingNonce: String?

    init() {
        guard firebaseReady, FirebaseAppIsConfigured.shared.value else { return }
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUserID = user?.uid
                self?.isAuthenticated = user != nil
                if user != nil {
                    self?.hasCompletedOnboarding = true
                }
            }
        }
    }

    deinit {
        if let authListenerHandle {
            Auth.auth().removeStateDidChangeListener(authListenerHandle)
        }
    }

    /// Called when the SignInWithAppleButton's request closure fires.
    /// Generates a nonce, stores it, and returns the SHA-256 hash for Apple.
    func prepareAppleSignInRequest(name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmedName.isEmpty ? "FriendBet Player" : trimmedName
        UserDefaults.standard.set(displayName, forKey: "friendbet.displayName")

        let nonce = randomNonceString()
        pendingNonce = nonce
        return sha256(nonce)
    }

    /// Called from the SignInWithAppleButton's onCompletion closure on success.
    func handleAppleAuthorization(_ authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let nonce = pendingNonce else {
            authError = "Sign in with Apple failed: could not read credentials."
            return
        }

        guard firebaseReady, FirebaseAppIsConfigured.shared.value else {
            authError = "Add GoogleService-Info.plist to the Xcode target to enable Firebase sign-in and sync."
            return
        }

        isBusy = true
        authError = nil
        pendingNonce = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: identityToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                currentUserID = result.user.uid
                hasCompletedOnboarding = true
                isAuthenticated = true
            } catch {
                authError = error.localizedDescription
            }
            isBusy = false
        }
    }

    /// Called from the SignInWithAppleButton's onCompletion closure on failure.
    func handleAppleError(_ error: Error) {
        // User cancelled — no need to surface an error
        if (error as? ASAuthorizationError)?.code != .canceled {
            authError = error.localizedDescription
        }
        isBusy = false
    }

    /// Fall back for preview / no Firebase configured.
    func signInDemo(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "FriendBet Player" : trimmedName
        displayName = finalName
        UserDefaults.standard.set(finalName, forKey: "friendbet.displayName")
        hasCompletedOnboarding = true
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUserID = nil
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
final class FirebaseAppIsConfigured {
    static let shared = FirebaseAppIsConfigured()
    let value: Bool

    private init() {
        value = FirebaseBootstrap.hasConfigurationFile
    }
}

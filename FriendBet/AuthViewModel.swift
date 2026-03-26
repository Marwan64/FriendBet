import Foundation
import FirebaseAuth

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

    func signInDemo(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "FriendBet Player" : trimmedName

        displayName = finalName
        UserDefaults.standard.set(finalName, forKey: "friendbet.displayName")

        guard firebaseReady, FirebaseAppIsConfigured.shared.value else {
            authError = "Add GoogleService-Info.plist to the Xcode target to enable Firebase sign-in and sync."
            return
        }

        isBusy = true
        authError = nil

        if Auth.auth().currentUser != nil {
            hasCompletedOnboarding = true
            isAuthenticated = true
            currentUserID = Auth.auth().currentUser?.uid
            isBusy = false
            return
        }

        Auth.auth().signInAnonymously { [weak self] result, error in
            Task { @MainActor in
                self?.isBusy = false
                if let error {
                    self?.authError = error.localizedDescription
                    return
                }

                self?.currentUserID = result?.user.uid
                self?.hasCompletedOnboarding = true
                self?.isAuthenticated = true
            }
        }
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
}

@MainActor
final class FirebaseAppIsConfigured {
    static let shared = FirebaseAppIsConfigured()
    let value: Bool

    private init() {
        value = FirebaseBootstrap.hasConfigurationFile
    }
}

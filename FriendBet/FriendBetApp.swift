import SwiftUI
import FirebaseCore

@main
struct FriendBetApp: App {
    @StateObject private var store = BetStore()
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseBootstrap.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(authViewModel)
        }
    }
}

enum FirebaseBootstrap {
    static var hasConfigurationFile: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static func configureIfPossible() {
        guard FirebaseApp.app() == nil else { return }
        guard hasConfigurationFile else { return }
        FirebaseApp.configure()
    }
}

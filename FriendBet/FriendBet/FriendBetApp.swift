import SwiftUI

@main
struct FriendBetApp: App {
    @StateObject private var store = BetStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

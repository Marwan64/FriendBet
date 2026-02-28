import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: BetStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BetsListView()
                .tabItem {
                    Label("Bets", systemImage: "list.bullet.clipboard")
                }
                .tag(0)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tag(1)
            
            PlayersView()
                .tabItem {
                    Label("Players", systemImage: "person.3")
                }
                .tag(2)
        }
        .accentColor(.indigo)
    }
}

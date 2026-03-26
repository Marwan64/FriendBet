import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BetStore
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingNewBet = false

    var body: some View {
        ZStack {
            AppGradientBackground()

            if authViewModel.isAuthenticated {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(showingNewBet: $showingNewBet)
                    }
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                    NavigationStack {
                        BetsListView()
                    }
                    .tabItem { Label("Bets", systemImage: "ticket.fill") }
                    .tag(1)

                    NavigationStack {
                        LeaderboardView()
                    }
                    .tabItem { Label("Leaders", systemImage: "chart.bar.fill") }
                    .tag(2)

                    NavigationStack {
                        PlayersView()
                    }
                    .tabItem { Label("Players", systemImage: "person.3.fill") }
                    .tag(3)
                }
                .tint(Color(hex: "F4C95D"))
                .sheet(isPresented: $showingNewBet) {
                    NavigationStack {
                        NewBetView()
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            } else {
                OnboardingView()
            }
        }
        .task(id: authViewModel.currentUserID) {
            store.connectSession(userID: authViewModel.currentUserID, preferredName: authViewModel.displayName)
        }
        .preferredColorScheme(.dark)
    }
}

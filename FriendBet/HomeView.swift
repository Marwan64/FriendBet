import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: BetStore
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var showingNewBet: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let featuredBet = store.featuredBet,
                   let challenger = store.player(for: featuredBet.challengerID),
                   let opponent = store.player(for: featuredBet.opponentID) {
                    BetHeroCard(bet: featuredBet, challenger: challenger, opponent: opponent)
                }

                statGrid

                SectionHeader(title: "Trending Bets", subtitle: "The bets pulling the most attention right now.")
                    .padding(.top, 8)

                ForEach(store.activeBets.prefix(3)) { bet in
                    if let challenger = store.player(for: bet.challengerID),
                       let opponent = store.player(for: bet.opponentID) {
                        NavigationLink {
                            BetDetailView(bet: bet)
                        } label: {
                            BetRowCard(bet: bet, challenger: challenger, opponent: opponent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewBet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(12)
                        .background(Color(hex: "F4C95D"), in: Circle())
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button("Sign Out") {
                    authViewModel.signOut()
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome back,")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.64))

                        Text(store.currentUser.name)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    AvatarView(player: store.currentUser, size: 58)
                }

                Text("Your league is hot this week. Three active bets are closing soon and your streak is still alive.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))

                HStack {
                    SecondaryChip(text: "\(store.currentUser.streak)-bet streak", systemImage: "flame.fill")
                    SecondaryChip(text: "\(store.currentUser.points) pts", systemImage: "star.fill")
                }

                if let syncError = store.syncError {
                    Text(syncError)
                        .font(.footnote)
                        .foregroundStyle(Color(hex: "FF8C68"))
                }
            }
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(title: "Active bets", value: "\(store.activeBets.count)", caption: "Closing over the next two weeks", color: Color(hex: "5FE7C4"))
            StatCard(title: "Your record", value: "\(store.currentUser.wins)-4", caption: "Wins this season", color: Color(hex: "FF8C68"))
            StatCard(title: "League pot", value: store.totalPotDisplay, caption: "Total bragging rights in motion", color: Color(hex: "F4C95D"))
            StatCard(title: "Pending invites", value: "\(store.pendingBets.count)", caption: "Needs response from friends", color: Color(hex: "87B7FF"))
        }
    }
}

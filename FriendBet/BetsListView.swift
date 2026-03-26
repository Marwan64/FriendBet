import SwiftUI

struct BetsListView: View {
    @EnvironmentObject private var store: BetStore
    @State private var selectedStatus: BetStatus = .active

    private var filteredBets: [Bet] {
        store.bets.filter { $0.status == selectedStatus }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "All Bets", subtitle: "Track what is live, waiting, and already settled.")

                Picker("Status", selection: $selectedStatus) {
                    ForEach(BetStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(filteredBets) { bet in
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
        .background(AppGradientBackground())
        .navigationTitle("Bets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

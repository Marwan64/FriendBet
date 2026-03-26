import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var store: BetStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Leaderboard", subtitle: "The friends everyone is chasing this month.")

                ForEach(Array(store.leaderboard().enumerated()), id: \.element.id) { index, player in
                    GlassCard {
                        HStack(spacing: 16) {
                            Text("#\(index + 1)")
                                .font(.title3.weight(.black))
                                .foregroundStyle(player.accent)
                                .frame(width: 34, alignment: .leading)

                            AvatarView(player: player, size: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(player.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(player.wins) wins • \(player.streak)-bet streak")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(player.points)")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("points")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .background(AppGradientBackground())
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
    }
}

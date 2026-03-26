import SwiftUI

struct BetDetailView: View {
    @EnvironmentObject private var store: BetStore
    let bet: Bet

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if let challenger = store.player(for: bet.challengerID),
                   let opponent = store.player(for: bet.opponentID) {
                    BetHeroCard(bet: bet, challenger: challenger, opponent: opponent)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 18) {
                            SectionHeader(title: "Bet Breakdown", subtitle: "Everything both sides agreed to.")

                            detailRow(title: "Stake", value: bet.stake)
                            detailRow(title: "Deadline", value: bet.dueDate.formatted(date: .abbreviated, time: .omitted))
                            detailRow(title: "Confidence", value: "\(bet.confidence)%")
                            detailRow(title: "Audience", value: "\(bet.watchers) watchers • \(bet.comments) comments")

                            Text(bet.details)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.78))
                                .padding(.top, 4)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(title: "Competitors", subtitle: "Who is on the line for this one.")

                            competitorCard(player: challenger, role: "Challenger")
                            competitorCard(player: opponent, role: "Opponent")
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .background(AppGradientBackground())
        .navigationTitle("Bet Detail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func competitorCard(player: Player, role: String) -> some View {
        HStack(spacing: 14) {
            AvatarView(player: player, size: 50)

            VStack(alignment: .leading, spacing: 5) {
                Text(player.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(role) • \(player.handle)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(player.points)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("points")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

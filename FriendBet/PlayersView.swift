import SwiftUI

struct PlayersView: View {
    @EnvironmentObject private var store: BetStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(title: "Players", subtitle: "Your league at a glance, with enough personality to feel alive.")

                ForEach(store.players) { player in
                    GlassCard {
                        HStack(spacing: 14) {
                            AvatarView(player: player, size: 58)

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(player.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    if player.id == store.currentUserID {
                                        Text("YOU")
                                            .font(.caption2.weight(.black))
                                            .foregroundStyle(.black.opacity(0.8))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "F4C95D"), in: Capsule())
                                    }
                                }

                                Text(player.handle)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.68))

                                HStack(spacing: 10) {
                                    SecondaryChip(text: "\(player.wins) wins", systemImage: "checkmark.seal.fill")
                                    SecondaryChip(text: "\(player.streak) streak", systemImage: "flame.fill")
                                }
                            }

                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 30)
        }
        .background(AppGradientBackground())
        .navigationTitle("Players")
        .navigationBarTitleDisplayMode(.inline)
    }
}

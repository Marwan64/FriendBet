import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var store: BetStore
    
    var rankedPlayers: [(Player, PlayerStats)] {
        store.players
            .map { ($0, store.stats(for: $0)) }
            .sorted { $0.1.wins > $1.1.wins }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if store.players.isEmpty {
                    Text("Add players to see the leaderboard!")
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Podium
                            if rankedPlayers.count >= 3 {
                                PodiumView(players: Array(rankedPlayers.prefix(3)))
                                    .padding(.top)
                            }
                            
                            // Full rankings
                            VStack(spacing: 10) {
                                ForEach(Array(rankedPlayers.enumerated()), id: \.offset) { i, item in
                                    LeaderboardRow(rank: i + 1, player: item.0, stats: item.1)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Leaderboard 🏆")
        }
    }
}

struct PodiumView: View {
    let players: [(Player, PlayerStats)]
    
    // reorder: 2nd, 1st, 3rd
    var podiumOrder: [(Player, PlayerStats, Int, CGFloat)] {
        guard players.count >= 3 else { return [] }
        return [
            (players[1].0, players[1].1, 2, 80),
            (players[0].0, players[0].1, 1, 110),
            (players[2].0, players[2].1, 3, 60),
        ]
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(podiumOrder, id: \.2) { player, stats, rank, height in
                VStack(spacing: 8) {
                    if rank == 1 {
                        Text("👑").font(.title2)
                    }
                    PlayerAvatar(player: player, size: rank == 1 ? 60 : 48)
                    Text(player.name)
                        .font(.caption.weight(.semibold))
                    Text("\(stats.wins)W / \(stats.losses)L")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(rank == 1 ? Color.yellow.opacity(0.3) :
                                  rank == 2 ? Color.gray.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(height: height)
                        Text("#\(rank)")
                            .font(.title3.weight(.black))
                            .foregroundColor(rank == 1 ? .yellow : .secondary)
                            .padding(.bottom, 8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        .padding(.horizontal)
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let player: Player
    let stats: PlayerStats
    
    var rankEmoji: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
    
    var body: some View {
        HStack(spacing: 14) {
            Text(rankEmoji)
                .font(rank <= 3 ? .title2 : .headline)
                .frame(width: 36)
            
            PlayerAvatar(player: player, size: 44)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    StatPill(label: "\(stats.wins)W", color: .green)
                    StatPill(label: "\(stats.losses)L", color: .red)
                    StatPill(label: "\(Int(stats.winRate * 100))%", color: .indigo)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("+$\(stats.totalWon, specifier: "%.0f")")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.green)
                if stats.owes > 0 {
                    Text("-$\(stats.owes, specifier: "%.0f") owed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

struct StatPill: View {
    let label: String
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

import SwiftUI

struct PlayersView: View {
    @EnvironmentObject var store: BetStore
    @State private var showAddPlayer = false
    @State private var selectedPlayer: Player? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                if store.players.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No players yet")
                            .font(.title2.weight(.semibold))
                        Text("Add your friends to start betting!")
                            .foregroundColor(.secondary)
                        Button("Add First Player") { showAddPlayer = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)
                    }
                } else {
                    List {
                        ForEach(store.players) { player in
                            Button { selectedPlayer = player } label: {
                                PlayerListRow(player: player,
                                              stats: store.stats(for: player))
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete { offsets in
                            offsets.forEach { store.deletePlayer(store.players[$0]) }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Players")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddPlayer = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showAddPlayer) {
                AddPlayerView()
            }
            .sheet(item: $selectedPlayer) { player in
                PlayerProfileView(player: player)
            }
        }
    }
}

struct PlayerListRow: View {
    let player: Player
    let stats: PlayerStats
    
    var body: some View {
        HStack(spacing: 14) {
            PlayerAvatar(player: player, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    StatPill(label: "\(stats.totalBets) bets", color: .blue)
                    StatPill(label: "\(stats.wins)W", color: .green)
                    if stats.owes > 0 {
                        StatPill(label: "owes $\(String(format: "%.0f", stats.owes))", color: .red)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Add Player
struct AddPlayerView: View {
    @EnvironmentObject var store: BetStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedEmoji = "🎯"
    
    let emojis = ["🎯","🏆","🎲","⚡","🔥","🚀","🎮","⚽","🏀","🎾","🎸","🎺","🎩","🦁","🐯","🦊","🐺","🦅","🌟","💎"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo.opacity(0.7), .purple.opacity(0.7)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 90, height: 90)
                    Text(selectedEmoji)
                        .font(.system(size: 44))
                }
                .padding(.top)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    TextField("Player name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pick an emoji").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                        .padding(.horizontal)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                selectedEmoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title)
                                    .padding(10)
                                    .background(selectedEmoji == emoji ? Color.indigo.opacity(0.2) : Color(.secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedEmoji == emoji ? Color.indigo : Color.clear, lineWidth: 2)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("New Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addPlayer(Player(name: name, emoji: selectedEmoji))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Player Profile
struct PlayerProfileView: View {
    @EnvironmentObject var store: BetStore
    let player: Player
    @Environment(\.dismiss) var dismiss
    
    var stats: PlayerStats { store.stats(for: player) }
    
    var myBets: [Bet] {
        store.bets.filter { $0.sides.contains(where: { $0.player.id == player.id }) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar + name
                    VStack(spacing: 10) {
                        PlayerAvatar(player: player, size: 80)
                        Text(player.name)
                            .font(.title.weight(.bold))
                    }
                    .padding(.top)
                    
                    // Stats grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        StatCard(title: "Total Bets",  value: "\(stats.totalBets)", color: .blue)
                        StatCard(title: "Win Rate",    value: "\(Int(stats.winRate * 100))%", color: .indigo)
                        StatCard(title: "Total Won",   value: "$\(String(format: "%.2f", stats.totalWon))", color: .green)
                        StatCard(title: "Outstanding", value: "$\(String(format: "%.2f", stats.owes))", color: stats.owes > 0 ? .red : .gray)
                    }
                    .padding(.horizontal)
                    
                    // Recent bets
                    if !myBets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Bets")
                                .font(.headline)
                                .padding(.horizontal)
                            ForEach(myBets.prefix(5)) { bet in
                                HStack {
                                    Image(systemName: bet.category.icon)
                                        .foregroundColor(bet.category.color)
                                    VStack(alignment: .leading) {
                                        Text(bet.title).font(.subheadline.weight(.semibold))
                                        Text(bet.status.rawValue).font(.caption).foregroundColor(bet.status.color)
                                    }
                                    Spacer()
                                    if bet.winnerId == player.id {
                                        Text("Won!").font(.caption.weight(.bold)).foregroundColor(.green)
                                    }
                                }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.weight(.black))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

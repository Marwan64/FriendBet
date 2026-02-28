import SwiftUI

struct BetDetailView: View {
    @EnvironmentObject var store: BetStore
    @State var bet: Bet
    @State private var showResolve = false
    @State private var showDispute = false
    @State private var resolveWinnerId: UUID? = nil
    @Environment(\.dismiss) var dismiss
    
    // Keep in sync with store
    var liveBet: Bet {
        store.bets.first(where: { $0.id == bet.id }) ?? bet
    }
    
    var body: some View {
        let b = liveBet
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                HeaderCard(bet: b)
                
                // Sides / wagers
                WagersCard(bet: b)
                
                // Actions
                ActionsCard(bet: b,
                            onAccept: { pid in store.acceptBet(betId: b.id, playerId: pid) },
                            onResolve: { showResolve = true },
                            onMarkPaid: { pid in store.markPaid(betId: b.id, playerId: pid) },
                            onDispute: { store.disputeBet(betId: b.id) })
                
                // Timeline
                TimelineCard(bet: b)
            }
            .padding()
        }
        .navigationTitle(b.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .confirmationDialog("Who won?", isPresented: $showResolve, titleVisibility: .visible) {
            ForEach(b.sides) { side in
                Button(side.player.name) {
                    store.resolveBet(betId: b.id, winnerId: side.player.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Header Card
struct HeaderCard: View {
    let bet: Bet
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: bet.category.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(bet.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bet.category.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    StatusBadge(status: bet.status)
                }
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total Pot")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(String(format: "%.2f", bet.totalPot))")
                        .font(.title.weight(.black))
                        .foregroundColor(.indigo)
                }
            }
            
            Divider()
            
            Text(bet.description)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let due = bet.dueDate {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                    Text("Due: ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(due, style: .date)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(due < Date() && bet.status != .completed ? .red : .primary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// MARK: - Wagers Card
struct WagersCard: View {
    let bet: Bet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Participants")
                .font(.headline)
            
            ForEach(bet.sides) { side in
                let isWinner = bet.winnerId == side.player.id
                let owesMoney = bet.status == .completed && bet.winnerId != nil && bet.winnerId != side.player.id
                let backgroundColor: Color = isWinner ? Color.yellow.opacity(0.1) : Color(.secondarySystemBackground)

                HStack(spacing: 12) {
                    PlayerAvatar(player: side.player, size: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(side.player.name)
                                .font(.subheadline.weight(.semibold))
                            if isWinner {
                                Image(systemName: "trophy.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        HStack(spacing: 4) {
                            SidePill(label: side.accepted ? "Accepted" : "Pending",
                                     color: side.accepted ? .green : .orange)
                            if owesMoney {
                                if side.paid {
                                    SidePill(label: "Paid ✓", color: .green)
                                } else {
                                    // Format amount as a separate Text to avoid specifier issues in interpolation
                                    SidePill(label: "Owes $\(String(format: "%.2f", side.wager))", color: .red)
                                }
                            }
                        }
                    }

                    Spacer()

                    // Show wager amount with explicit Text formatting
                    Text("$\(String(format: "%.2f", side.wager))")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.indigo)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundColor)
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct SidePill: View {
    let label: String
    let color: Color
    
    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Actions Card
struct ActionsCard: View {
    let bet: Bet
    let onAccept: (UUID) -> Void
    let onResolve: () -> Void
    let onMarkPaid: (UUID) -> Void
    let onDispute: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            // Accept pending
            let unaccepted = bet.sides.filter { !$0.accepted }
            if bet.status == .pending && !unaccepted.isEmpty {
                ForEach(unaccepted) { side in
                    ActionButton(
                        label: "\(side.player.name) – Accept Bet",
                        icon: "checkmark.circle",
                        color: .green
                    ) { onAccept(side.player.id) }
                }
            }
            
            // Resolve
            if bet.status == .active {
                ActionButton(label: "Declare Winner 🏆", icon: "trophy", color: .indigo, action: onResolve)
                ActionButton(label: "Dispute Bet", icon: "exclamationmark.triangle", color: .red, action: onDispute)
            }
            
            // Mark paid
            if bet.status == .completed {
                let unpaid = bet.sides.filter { !$0.paid && $0.player.id != bet.winnerId }
                if unpaid.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text("All debts settled!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.green)
                    }
                } else {
                    ForEach(unpaid) { side in
                        ActionButton(
                            label: "\(side.player.name) Paid $\(String(format: "%.2f", side.wager))",
                            icon: "dollarsign.circle",
                            color: .teal
                        ) { onMarkPaid(side.player.id) }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Timeline Card
struct TimelineCard: View {
    let bet: Bet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
            
            TimelineRow(icon: "plus.circle.fill", color: .indigo,
                        title: "Bet Created",
                        date: bet.createdAt)
            
            if bet.allAccepted && bet.status != .pending {
                TimelineRow(icon: "flame.fill", color: .orange,
                            title: "Bet Activated — it's on!",
                            date: bet.createdAt)
            }
            
            if let resolved = bet.resolvedAt {
                TimelineRow(icon: "checkmark.seal.fill", color: .green,
                            title: "Resolved – \(bet.winner?.name ?? "?") won!",
                            date: resolved)
            }
            
            if bet.status == .disputed {
                TimelineRow(icon: "exclamationmark.triangle.fill", color: .red,
                            title: "Bet Disputed",
                            date: Date())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct TimelineRow: View {
    let icon: String
    let color: Color
    let title: String
    let date: Date
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(date, style: .relative) + Text(" ago")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}


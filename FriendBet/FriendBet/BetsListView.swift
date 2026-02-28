import SwiftUI

struct BetsListView: View {
    @EnvironmentObject var store: BetStore
    @State private var showNewBet = false
    @State private var filterStatus: BetStatus? = nil
    @State private var searchText = ""
    
    var filteredBets: [Bet] {
        store.bets.filter { bet in
            let matchesStatus = filterStatus == nil || bet.status == filterStatus
            let matchesSearch = searchText.isEmpty ||
                bet.title.localizedCaseInsensitiveContains(searchText) ||
                bet.description.localizedCaseInsensitiveContains(searchText)
            return matchesStatus && matchesSearch
        }
    }
    
    var outstandingDebt: Double {
        store.bets.filter { $0.status == .completed && $0.winnerId != nil }
            .flatMap { $0.sides }
            .filter { !$0.paid }
            .reduce(0) { $0 + $1.wager }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Debt banner
                    if outstandingDebt > 0 {
                        DebtBanner(amount: outstandingDebt)
                    }
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(title: "All", isSelected: filterStatus == nil) {
                                filterStatus = nil
                            }
                            ForEach(BetStatus.allCases, id: \.self) { status in
                                FilterChip(title: status.rawValue, isSelected: filterStatus == status,
                                           color: status.color) {
                                    filterStatus = filterStatus == status ? nil : status
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    
                    if filteredBets.isEmpty {
                        EmptyBetsView(hasFilter: filterStatus != nil || !searchText.isEmpty) {
                            showNewBet = true
                        }
                    } else {
                        List {
                            ForEach(filteredBets) { bet in
                                NavigationLink(destination: BetDetailView(bet: bet)) {
                                    BetRowView(bet: bet)
                                }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                            .onDelete { offsets in
                                offsets.forEach { idx in
                                    store.deleteBet(filteredBets[idx])
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("FriendBet 🤝")
            .searchable(text: $searchText, prompt: "Search bets...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewBet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.indigo)
                    }
                }
            }
            .sheet(isPresented: $showNewBet) {
                NewBetView()
            }
        }
    }
}

// MARK: - Subviews

struct DebtBanner: View {
    let amount: Double
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
            Text("$\(amount, specifier: "%.2f") in unpaid debts!")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.red.gradient)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = .indigo
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color(.secondarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct BetRowView: View {
    let bet: Bet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Category icon
                Image(systemName: bet.category.icon)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .background(bet.category.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(bet.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(bet.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(bet.totalPot, specifier: "%.2f")")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.indigo)
                    StatusBadge(status: bet.status)
                }
            }
            
            // Players row
            HStack(spacing: -6) {
                ForEach(bet.sides) { side in
                    PlayerAvatar(player: side.player, size: 28)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
                Spacer()
                
                if let winner = bet.winner {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(winner.name)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                } else if let due = bet.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(due, style: .relative)
                            .font(.caption)
                            .foregroundColor(due < Date() ? .red : .secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

struct StatusBadge: View {
    let status: BetStatus
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.system(size: 9))
            Text(status.rawValue)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .clipShape(Capsule())
    }
}

struct EmptyBetsView: View {
    let hasFilter: Bool
    let onNew: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: hasFilter ? "magnifyingglass" : "hand.raised.fingers.spread")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            Text(hasFilter ? "No matching bets" : "No bets yet!")
                .font(.title2.weight(.semibold))
            Text(hasFilter ? "Try changing your filter" : "Create your first bet and start the competition")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if !hasFilter {
                Button(action: onNew) {
                    Label("Create a Bet", systemImage: "plus")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.indigo.gradient)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding()
    }
}

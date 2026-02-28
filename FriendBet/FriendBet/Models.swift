import Foundation
import SwiftUI

// MARK: - Models

enum BetStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case active = "Active"
    case completed = "Completed"
    case disputed = "Disputed"
    
    var color: Color {
        switch self {
        case .pending:   return .orange
        case .active:    return .blue
        case .completed: return .green
        case .disputed:  return .red
        }
    }
    
    var icon: String {
        switch self {
        case .pending:   return "clock"
        case .active:    return "flame"
        case .completed: return "checkmark.seal.fill"
        case .disputed:  return "exclamationmark.triangle"
        }
    }
}

struct Player: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct BetSide: Identifiable, Codable {
    var id: UUID = UUID()
    var player: Player
    var wager: Double          // what they put in
    var accepted: Bool = false
    var paid: Bool = false
}

struct Bet: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var category: BetCategory
    var status: BetStatus
    var sides: [BetSide]       // usually 2 sides but can be more
    var createdAt: Date = Date()
    var resolvedAt: Date?
    var winnerId: UUID?         // winning player id
    var createdBy: UUID         // player who created the bet
    var dueDate: Date?
    
    var totalPot: Double {
        sides.reduce(0) { $0 + $1.wager }
    }
    
    var allAccepted: Bool {
        sides.allSatisfy { $0.accepted }
    }
    
    var winner: Player? {
        guard let wid = winnerId else { return nil }
        return sides.first(where: { $0.player.id == wid })?.player
    }
    
    var unpaidSides: [BetSide] {
        sides.filter { !$0.paid && $0.player.id != winnerId }
    }
}

enum BetCategory: String, Codable, CaseIterable {
    case sports     = "Sports"
    case games      = "Games"
    case school     = "School"
    case challenges = "Challenges"
    case trivia     = "Trivia"
    case other      = "Other"
    
    var icon: String {
        switch self {
        case .sports:     return "sportscourt"
        case .games:      return "gamecontroller"
        case .school:     return "graduationcap"
        case .challenges: return "bolt"
        case .trivia:     return "questionmark.bubble"
        case .other:      return "star"
        }
    }
    
    var color: Color {
        switch self {
        case .sports:     return .blue
        case .games:      return .purple
        case .school:     return .green
        case .challenges: return .orange
        case .trivia:     return .yellow
        case .other:      return .gray
        }
    }
}

// MARK: - Store

class BetStore: ObservableObject {
    @Published var players: [Player] = []
    @Published var bets: [Bet] = []
    
    private let playersKey = "friendbet_players"
    private let betsKey    = "friendbet_bets"
    
    init() {
        load()
        if players.isEmpty { seedDemo() }
    }
    
    // MARK: Player ops
    func addPlayer(_ player: Player) {
        players.append(player)
        save()
    }
    
    func deletePlayer(_ player: Player) {
        players.removeAll { $0.id == player.id }
        save()
    }
    
    // MARK: Bet ops
    func addBet(_ bet: Bet) {
        bets.insert(bet, at: 0)
        save()
    }
    
    func updateBet(_ bet: Bet) {
        if let idx = bets.firstIndex(where: { $0.id == bet.id }) {
            bets[idx] = bet
            save()
        }
    }
    
    func deleteBet(_ bet: Bet) {
        bets.removeAll { $0.id == bet.id }
        save()
    }
    
    func acceptBet(betId: UUID, playerId: UUID) {
        guard let bi = bets.firstIndex(where: { $0.id == betId }),
              let si = bets[bi].sides.firstIndex(where: { $0.player.id == playerId }) else { return }
        bets[bi].sides[si].accepted = true
        if bets[bi].allAccepted { bets[bi].status = .active }
        save()
    }
    
    func resolveBet(betId: UUID, winnerId: UUID) {
        guard let bi = bets.firstIndex(where: { $0.id == betId }) else { return }
        bets[bi].winnerId = winnerId
        bets[bi].status = .completed
        bets[bi].resolvedAt = Date()
        save()
    }
    
    func markPaid(betId: UUID, playerId: UUID) {
        guard let bi = bets.firstIndex(where: { $0.id == betId }),
              let si = bets[bi].sides.firstIndex(where: { $0.player.id == playerId }) else { return }
        bets[bi].sides[si].paid = true
        save()
    }
    
    func disputeBet(betId: UUID) {
        guard let bi = bets.firstIndex(where: { $0.id == betId }) else { return }
        bets[bi].status = .disputed
        save()
    }
    
    // MARK: Stats
    func stats(for player: Player) -> PlayerStats {
        let myBets = bets.filter { $0.sides.contains(where: { $0.player.id == player.id }) }
        let won = myBets.filter { $0.winnerId == player.id }
        let lost = myBets.filter { $0.status == .completed && $0.winnerId != nil && $0.winnerId != player.id }
        let totalWon = won.reduce(0.0) { $0 + $1.totalPot }
        let totalLost = lost.reduce(0.0) { sum, bet in
            sum + (bet.sides.first(where: { $0.player.id == player.id })?.wager ?? 0)
        }
        let owes = bets.filter {
            $0.status == .completed &&
            $0.winnerId != nil &&
            $0.winnerId != player.id &&
            ($0.sides.first(where: { $0.player.id == player.id })?.paid == false)
        }.reduce(0.0) { sum, bet in
            sum + (bet.sides.first(where: { $0.player.id == player.id })?.wager ?? 0)
        }
        return PlayerStats(totalBets: myBets.count, wins: won.count, losses: lost.count,
                           totalWon: totalWon, totalLost: totalLost, owes: owes)
    }
    
    // MARK: Persistence
    private func save() {
        if let pd = try? JSONEncoder().encode(players) { UserDefaults.standard.set(pd, forKey: playersKey) }
        if let bd = try? JSONEncoder().encode(bets)    { UserDefaults.standard.set(bd, forKey: betsKey) }
    }
    
    private func load() {
        if let pd = UserDefaults.standard.data(forKey: playersKey),
           let p  = try? JSONDecoder().decode([Player].self, from: pd) { players = p }
        if let bd = UserDefaults.standard.data(forKey: betsKey),
           let b  = try? JSONDecoder().decode([Bet].self, from: bd)    { bets = b }
    }
    
    private func seedDemo() {
        let alex  = Player(name: "Alex",  emoji: "🏆")
        let jamie = Player(name: "Jamie", emoji: "🎯")
        let sam   = Player(name: "Sam",   emoji: "🎲")
        players = [alex, jamie, sam]
        
        var bet1 = Bet(
            title: "Ping Pong Rematch",
            description: "Best of 5 games. No spin serves allowed.",
            category: .sports,
            status: .active,
            sides: [
                BetSide(player: alex,  wager: 5.00, accepted: true),
                BetSide(player: jamie, wager: 5.00, accepted: true)
            ],
            createdBy: alex.id
        )
        bet1.dueDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        
        var bet2 = Bet(
            title: "Math Test Score",
            description: "Whoever scores higher on Friday's calc test wins.",
            category: .school,
            status: .pending,
            sides: [
                BetSide(player: sam,  wager: 10.00, accepted: true),
                BetSide(player: alex, wager: 10.00, accepted: false)
            ],
            createdBy: sam.id
        )
        bet2.dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        
        var bet3 = Bet(
            title: "Hot Sauce Challenge",
            description: "Who can finish the whole bottle without tapping out?",
            category: .challenges,
            status: .completed,
            sides: [
                BetSide(player: jamie, wager: 3.00, accepted: true, paid: true),
                BetSide(player: sam,   wager: 3.00, accepted: true, paid: false)
            ],
            createdBy: jamie.id
        )
        bet3.winnerId = jamie.id
        bet3.resolvedAt = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        
        bets = [bet1, bet2, bet3]
        save()
    }
}

struct PlayerStats {
    let totalBets: Int
    let wins: Int
    let losses: Int
    let totalWon: Double
    let totalLost: Double
    let owes: Double
    
    var winRate: Double {
        guard wins + losses > 0 else { return 0 }
        return Double(wins) / Double(wins + losses)
    }
}

import Foundation
@preconcurrency import FirebaseFirestore

@MainActor
final class BetStore: ObservableObject {
    @Published var currentUserID: String
    @Published var currentUserName: String
    @Published var players: [Player]
    @Published var bets: [Bet]
    @Published var isLoading = false
    @Published var syncError: String?

    private var playerListener: ListenerRegistration?
    private var betListener: ListenerRegistration?
    private var hasSeededDemoData = false

    private var db: Firestore? {
        FirebaseBootstrap.hasConfigurationFile ? Firestore.firestore() : nil
    }

    init() {
        let players = BetStore.samplePlayers
        self.players = players
        self.currentUserID = players[0].id
        self.currentUserName = players[0].name
        self.bets = BetStore.sampleBets(players: players)
    }

    var currentUser: Player {
        players.first(where: { $0.id == currentUserID }) ??
        Player(
            id: currentUserID,
            name: currentUserName,
            handle: "@\(currentUserName.lowercased().replacingOccurrences(of: " ", with: ""))",
            avatar: String(currentUserName.prefix(1)),
            points: 0,
            wins: 0,
            streak: 0,
            accentHex: "FF8C68"
        )
    }

    var activeBets: [Bet] {
        bets.filter { $0.status == .active }
            .sorted { $0.dueDate < $1.dueDate }
    }

    var pendingBets: [Bet] {
        bets.filter { $0.status == .pending }
    }

    var settledBets: [Bet] {
        bets.filter { $0.status == .settled }
            .sorted { $0.dueDate > $1.dueDate }
    }

    var featuredBet: Bet? {
        activeBets.max(by: { $0.watchers < $1.watchers })
    }

    var totalPotDisplay: String {
        "$\(bets.count * 18)k"
    }

    func player(for id: String) -> Player? {
        players.first(where: { $0.id == id })
    }

    func connectSession(userID: String?, preferredName: String) {
        currentUserName = preferredName.isEmpty ? "FriendBet Player" : preferredName

        guard let userID else {
            detachListeners()
            currentUserID = Self.samplePlayers[0].id
            players = Self.samplePlayers
            bets = Self.sampleBets(players: players)
            return
        }

        currentUserID = userID

        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        isLoading = true
        syncError = nil
        ensureCurrentUserProfile(in: db, userID: userID, preferredName: currentUserName)
        attachPlayersListener(in: db)
        attachBetsListener(in: db)
        seedDemoDataIfNeeded(in: db, currentUserID: userID)
    }

    func createBet(title: String, subtitle: String, category: BetCategory, stake: String, challenger: UUID, opponent: UUID, details: String) {
        createBet(title: title, subtitle: subtitle, category: category, stake: stake, challenger: "\(challenger)", opponent: "\(opponent)", details: details)
    }

    func createBet(title: String, subtitle: String, category: BetCategory, stake: String, challenger: String, opponent: String, details: String) {
        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        let bet = Bet(
            id: UUID().uuidString,
            title: title,
            subtitle: subtitle,
            category: category,
            stake: stake,
            dueDate: Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date(),
            status: .pending,
            challengerID: challenger,
            opponentID: opponent,
            watchers: Int.random(in: 8...42),
            comments: Int.random(in: 2...16),
            confidence: Int.random(in: 58...88),
            winnerID: nil,
            details: details,
            createdAt: Date()
        )

        db.collection("bets").document(bet.id).setData(bet.firestoreData) { [weak self] error in
            Task { @MainActor in
                self?.syncError = error?.localizedDescription
            }
        }
    }

    func leaderboard() -> [Player] {
        players.sorted {
            if $0.points == $1.points {
                return $0.wins > $1.wins
            }
            return $0.points > $1.points
        }
    }

    private func attachPlayersListener(in db: Firestore) {
        playerListener?.remove()
        playerListener = db.collection("players").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if let error {
                    self?.syncError = error.localizedDescription
                    self?.isLoading = false
                    return
                }

                let players = snapshot?.documents.compactMap(Player.fromSnapshot).sorted(by: { $0.points > $1.points }) ?? []
                if !players.isEmpty {
                    self?.players = players
                }
                self?.isLoading = false
            }
        }
    }

    private func attachBetsListener(in db: Firestore) {
        betListener?.remove()
        betListener = db.collection("bets").addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if let error {
                    self?.syncError = error.localizedDescription
                    self?.isLoading = false
                    return
                }

                let bets = snapshot?.documents.compactMap(Bet.fromSnapshot).sorted(by: { $0.createdAt > $1.createdAt }) ?? []
                if !bets.isEmpty {
                    self?.bets = bets
                }
                self?.isLoading = false
            }
        }
    }

    private func ensureCurrentUserProfile(in db: Firestore, userID: String, preferredName: String) {
        let baseName = preferredName.isEmpty ? "FriendBet Player" : preferredName
        let handleSeed = baseName.lowercased().replacingOccurrences(of: " ", with: "")
        let profile = Player(
            id: userID,
            name: baseName,
            handle: "@\(String(handleSeed.prefix(16)))",
            avatar: String(baseName.prefix(1)),
            points: 980,
            wins: 0,
            streak: 0,
            accentHex: "FF8C68"
        )

        db.collection("players").document(userID).setData(profile.firestoreData, merge: true)
    }

    private func seedDemoDataIfNeeded(in db: Firestore, currentUserID: String) {
        guard !hasSeededDemoData else { return }
        hasSeededDemoData = true

        db.collection("players").getDocuments { [weak self] snapshot, error in
            guard error == nil else { return }
            guard let self else { return }
            guard (snapshot?.documents.count ?? 0) <= 1 else { return }

            let db = db
            Task { @MainActor in
                let seededPlayers = Self.seedPlayers(excluding: currentUserID)
                for player in seededPlayers {
                    db.collection("players").document(player.id).setData(player.firestoreData, merge: true)
                }

                let allPlayers = [self.currentUser] + seededPlayers
                let seededBets = Self.seedBets(players: allPlayers, currentUserID: currentUserID)
                for bet in seededBets {
                    db.collection("bets").document(bet.id).setData(bet.firestoreData, merge: true)
                }
            }
        }
    }

    private func detachListeners() {
        playerListener?.remove()
        playerListener = nil
        betListener?.remove()
        betListener = nil
    }

    private static let samplePlayers: [Player] = [
        Player(id: "local-marwan", name: "Marwan Warnick", handle: "@marwan", avatar: "M", points: 1420, wins: 18, streak: 4, accentHex: "FF8C68"),
        Player(id: "local-avery", name: "Avery Stone", handle: "@avery", avatar: "A", points: 1380, wins: 16, streak: 6, accentHex: "5FE7C4"),
        Player(id: "local-jordan", name: "Jordan Lee", handle: "@jordan", avatar: "J", points: 1265, wins: 14, streak: 3, accentHex: "87B7FF"),
        Player(id: "local-sam", name: "Sam Rivera", handle: "@sam", avatar: "S", points: 1195, wins: 13, streak: 2, accentHex: "D9A7FF"),
        Player(id: "local-taylor", name: "Taylor Brooks", handle: "@taylor", avatar: "T", points: 1110, wins: 11, streak: 1, accentHex: "F4C95D")
    ]

    private static func sampleBets(players: [Player]) -> [Bet] {
        [
            Bet(id: "local-bet-1", title: "Lakers make the conference finals", subtitle: "A season-long rivalry bet heating up the group chat.", category: .sports, stake: "$200 dinner tab", dueDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date(), status: .active, challengerID: players[0].id, opponentID: players[1].id, watchers: 48, comments: 12, confidence: 74, winnerID: nil, details: "If the Lakers miss the finals, Marwan covers the full playoff watch-party bill. If they get there, Avery wears gold for a week.", createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()),
            Bet(id: "local-bet-2", title: "No social media after 10pm for 14 days", subtitle: "A wellness challenge with real bragging rights.", category: .lifestyle, stake: "Weekend coffee run", dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(), status: .active, challengerID: players[2].id, opponentID: players[3].id, watchers: 31, comments: 9, confidence: 69, winnerID: nil, details: "Screen time screenshots settle the score. Any post or doomscroll session after 10pm counts as a miss.", createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()),
            Bet(id: "local-bet-3", title: "Opening weekend box office winner", subtitle: "Movie predictions with a little extra spice.", category: .entertainment, stake: "$50", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(), status: .pending, challengerID: players[1].id, opponentID: players[4].id, watchers: 19, comments: 4, confidence: 62, winnerID: nil, details: "Whoever picks the top-grossing release wins. In a tie, total domestic gross on Monday morning settles it.", createdAt: Date()),
            Bet(id: "local-bet-4", title: "First to close three client deals", subtitle: "Friendly sales pressure, public accountability.", category: .money, stake: "Loser buys celebratory steak dinner", dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(), status: .settled, challengerID: players[3].id, opponentID: players[0].id, watchers: 54, comments: 15, confidence: 91, winnerID: players[0].id, details: "Sam started hot, but Marwan closed hard in the final week and took the win by Friday afternoon.", createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()),
            Bet(id: "local-bet-5", title: "Run a sub-50 minute 10K this month", subtitle: "Two runners, one leaderboard, zero excuses.", category: .sports, stake: "Custom race-day kit", dueDate: Calendar.current.date(byAdding: .day, value: 9, to: Date()) ?? Date(), status: .active, challengerID: players[4].id, opponentID: players[2].id, watchers: 27, comments: 6, confidence: 66, winnerID: nil, details: "Only tracked outdoor runs count. Each runner gets as many attempts as they want before month-end.", createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date())
        ]
    }

    private static func seedPlayers(excluding currentUserID: String) -> [Player] {
        [
            Player(id: "seed-avery", name: "Avery Stone", handle: "@avery", avatar: "A", points: 1380, wins: 16, streak: 6, accentHex: "5FE7C4"),
            Player(id: "seed-jordan", name: "Jordan Lee", handle: "@jordan", avatar: "J", points: 1265, wins: 14, streak: 3, accentHex: "87B7FF"),
            Player(id: "seed-sam", name: "Sam Rivera", handle: "@sam", avatar: "S", points: 1195, wins: 13, streak: 2, accentHex: "D9A7FF"),
            Player(id: "seed-taylor", name: "Taylor Brooks", handle: "@taylor", avatar: "T", points: 1110, wins: 11, streak: 1, accentHex: "F4C95D")
        ].filter { $0.id != currentUserID }
    }

    private static func seedBets(players: [Player], currentUserID: String) -> [Bet] {
        let current = players.first(where: { $0.id == currentUserID }) ?? players[0]
        let rivals = players.filter { $0.id != current.id }
        guard rivals.count >= 3 else { return [] }

        return [
            Bet(id: "seed-bet-1", title: "Lakers make the conference finals", subtitle: "A season-long rivalry bet heating up the group chat.", category: .sports, stake: "$200 dinner tab", dueDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date(), status: .active, challengerID: current.id, opponentID: rivals[0].id, watchers: 48, comments: 12, confidence: 74, winnerID: nil, details: "If the Lakers miss the finals, the challenger covers the full playoff watch-party bill. If they get there, the opponent wears team colors for a week.", createdAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()),
            Bet(id: "seed-bet-2", title: "No social media after 10pm for 14 days", subtitle: "A wellness challenge with real bragging rights.", category: .lifestyle, stake: "Weekend coffee run", dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date(), status: .active, challengerID: rivals[1].id, opponentID: current.id, watchers: 31, comments: 9, confidence: 69, winnerID: nil, details: "Screen time screenshots settle the score. Any post or doomscroll session after 10pm counts as a miss.", createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()),
            Bet(id: "seed-bet-3", title: "Opening weekend box office winner", subtitle: "Movie predictions with a little extra spice.", category: .entertainment, stake: "$50", dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(), status: .pending, challengerID: rivals[0].id, opponentID: rivals[2].id, watchers: 19, comments: 4, confidence: 62, winnerID: nil, details: "Whoever picks the top-grossing release wins. In a tie, total domestic gross on Monday morning settles it.", createdAt: Date())
        ]
    }
}

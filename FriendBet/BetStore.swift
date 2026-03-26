import Foundation
@preconcurrency import FirebaseFirestore

@MainActor
final class BetStore: ObservableObject {
    @Published var currentUserID: String
    @Published var currentUserName: String
    @Published var groups: [Group]
    @Published var activeGroupID: String?
    @Published var players: [Player]
    @Published var bets: [Bet]
    @Published var isLoading = false
    @Published var syncError: String?

    private var groupsListener: ListenerRegistration?
    private var playerListener: ListenerRegistration?
    private var betListener: ListenerRegistration?

    private var db: Firestore? {
        FirebaseBootstrap.hasConfigurationFile ? Firestore.firestore() : nil
    }

    init() {
        let players = BetStore.samplePlayers
        let groups = BetStore.sampleGroups
        self.players = players
        self.groups = groups
        self.activeGroupID = groups.first?.id
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

    var activeGroup: Group? {
        groups.first(where: { $0.id == activeGroupID })
    }

    var availableOpponents: [Player] {
        players.filter { $0.id != currentUserID }
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
            let players = Self.samplePlayers
            let groups = Self.sampleGroups
            currentUserID = players[0].id
            currentUserName = players[0].name
            self.groups = groups
            activeGroupID = groups.first?.id
            self.players = players
            bets = Self.sampleBets(players: players)
            syncError = nil
            return
        }

        currentUserID = userID

        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        isLoading = true
        syncError = nil
        attachGroupsListener(in: db, userID: userID)
    }

    func selectGroup(id: String) {
        guard activeGroupID != id else { return }
        activeGroupID = id
        persistActiveGroupID(id)

        guard let db else { return }
        attachGroupContentListeners(in: db, groupID: id)
    }

    func createGroup(named rawName: String) {
        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "\(currentUserName)'s Group" : trimmedName
        let groupID = UUID().uuidString
        let group = Group(
            id: groupID,
            name: name,
            inviteCode: Self.makeInviteCode(),
            ownerID: currentUserID,
            accentHex: Self.groupAccentPalette.randomElement() ?? "87B7FF",
            memberIDs: [currentUserID],
            memberCount: 1,
            createdAt: Date()
        )

        isLoading = true
        syncError = nil

        let groupRef = db.collection("groups").document(groupID)
        let inviteCodeRef = db.collection("inviteCodes").document(group.inviteCode)
        let playerRef = groupRef.collection("players").document(currentUserID)
        let batch = db.batch()
        batch.setData(group.firestoreData, forDocument: groupRef)
        batch.setData([
            "groupID": groupID,
            "ownerID": currentUserID,
            "createdAt": Timestamp(date: Date())
        ], forDocument: inviteCodeRef)
        batch.setData(makeCurrentUserProfile().firestoreData, forDocument: playerRef, merge: true)

        batch.commit { [weak self] error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.syncError = self.friendlyFirestoreMessage(for: error, during: "create a private group")
                    self.isLoading = false
                    return
                }

                self.upsertLocalGroup(group)
                self.players = [self.makeCurrentUserProfile()]
                self.bets = []
                self.selectGroup(id: groupID)
                self.isLoading = false
            }
        }
    }

    func joinGroup(inviteCode rawCode: String) {
        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        let inviteCode = rawCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !inviteCode.isEmpty else {
            syncError = "Enter an invite code to join a group."
            return
        }

        isLoading = true
        syncError = nil

        db.collection("inviteCodes")
            .document(inviteCode)
            .getDocument { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.syncError = self.friendlyFirestoreMessage(for: error, during: "join a group")
                        self.isLoading = false
                        return
                    }

                    guard let groupID = snapshot?.data()?["groupID"] as? String else {
                        self.syncError = "That invite code does not match a group."
                        self.isLoading = false
                        return
                    }

                    let groupRef = db.collection("groups").document(groupID)
                    groupRef.getDocument { snapshot, error in
                        Task { @MainActor in
                            if let error {
                                self.syncError = self.friendlyFirestoreMessage(for: error, during: "join a group")
                                self.isLoading = false
                                return
                            }

                            guard let snapshot,
                                  var group = Group.fromSnapshot(snapshot) else {
                                self.syncError = "That group could not be loaded."
                                self.isLoading = false
                                return
                            }

                            if group.memberIDs.contains(self.currentUserID) {
                                self.upsertLocalGroup(group)
                                self.selectGroup(id: group.id)
                                self.isLoading = false
                                return
                            }

                            group.memberIDs.append(self.currentUserID)
                            group.memberCount = group.memberIDs.count

                            let batch = db.batch()
                            batch.setData(group.firestoreData, forDocument: groupRef, merge: true)
                            batch.setData(self.makeCurrentUserProfile().firestoreData, forDocument: groupRef.collection("players").document(self.currentUserID), merge: true)
                            batch.commit { error in
                                Task { @MainActor in
                                    if let error {
                                        self.syncError = self.friendlyFirestoreMessage(for: error, during: "join a group")
                                        self.isLoading = false
                                        return
                                    }

                                    self.upsertLocalGroup(group)
                                    self.players = self.players.contains(where: { $0.id == self.currentUserID }) ? self.players : [self.makeCurrentUserProfile()]
                                    self.bets = []
                                    self.selectGroup(id: group.id)
                                    self.isLoading = false
                                }
                            }
                        }
                    }
                }
            }
    }

    func createBet(title: String, subtitle: String, category: BetCategory, stake: String, challenger: UUID, opponent: UUID, details: String) {
        createBet(title: title, subtitle: subtitle, category: category, stake: stake, challenger: "\(challenger)", opponent: "\(opponent)", details: details)
    }

    func createBet(title: String, subtitle: String, category: BetCategory, stake: String, challenger: String, opponent: String, details: String) {
        guard let db else {
            syncError = "Firebase configuration file is missing."
            return
        }

        guard let activeGroupID else {
            syncError = "Create or join a group before publishing bets."
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

        db.collection("groups")
            .document(activeGroupID)
            .collection("bets")
            .document(bet.id)
            .setData(bet.firestoreData) { [weak self] error in
                Task { @MainActor in
                    guard let self, let error else { return }
                    self.syncError = self.friendlyFirestoreMessage(for: error, during: "create a bet")
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

    private func attachGroupsListener(in db: Firestore, userID: String) {
        groupsListener?.remove()
        groupsListener = db.collection("groups")
            .whereField("memberIDs", arrayContains: userID)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }

                    if let error {
                        self.syncError = self.friendlyFirestoreMessage(for: error, during: "load your groups")
                        self.isLoading = false
                        return
                    }

                    let fetchedGroups = snapshot?.documents
                        .compactMap(Group.fromSnapshot)
                        .sorted(by: { $0.createdAt > $1.createdAt }) ?? []

                    self.groups = fetchedGroups

                    guard !fetchedGroups.isEmpty else {
                        self.activeGroupID = nil
                        self.players = []
                        self.bets = []
                        self.detachGroupContentListeners()
                        self.isLoading = false
                        return
                    }

                    let preferredGroupID = self.persistedActiveGroupID(for: userID)
                    let resolvedGroupID: String
                    if let activeGroupID = self.activeGroupID,
                       fetchedGroups.contains(where: { $0.id == activeGroupID }) {
                        resolvedGroupID = activeGroupID
                    } else if let preferredGroupID,
                              fetchedGroups.contains(where: { $0.id == preferredGroupID }) {
                        resolvedGroupID = preferredGroupID
                    } else {
                        resolvedGroupID = fetchedGroups[0].id
                    }

                    self.activeGroupID = resolvedGroupID
                    self.persistActiveGroupID(resolvedGroupID)
                    self.attachGroupContentListeners(in: db, groupID: resolvedGroupID)
                }
            }
    }

    private func attachGroupContentListeners(in db: Firestore, groupID: String) {
        ensureCurrentUserProfile(in: db, groupID: groupID)
        attachPlayersListener(in: db, groupID: groupID)
        attachBetsListener(in: db, groupID: groupID)
    }

    private func attachPlayersListener(in db: Firestore, groupID: String) {
        playerListener?.remove()
        playerListener = db.collection("groups")
            .document(groupID)
            .collection("players")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error {
                        self?.syncError = self?.friendlyFirestoreMessage(for: error, during: "load group members")
                        self?.isLoading = false
                        return
                    }

                    let players = snapshot?.documents
                        .compactMap(Player.fromSnapshot)
                        .sorted(by: { $0.points > $1.points }) ?? []
                    self?.players = players
                    self?.isLoading = false
                }
            }
    }

    private func attachBetsListener(in db: Firestore, groupID: String) {
        betListener?.remove()
        betListener = db.collection("groups")
            .document(groupID)
            .collection("bets")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error {
                        self?.syncError = self?.friendlyFirestoreMessage(for: error, during: "load group bets")
                        self?.isLoading = false
                        return
                    }

                    let bets = snapshot?.documents
                        .compactMap(Bet.fromSnapshot)
                        .sorted(by: { $0.createdAt > $1.createdAt }) ?? []
                    self?.bets = bets
                    self?.isLoading = false
                }
            }
    }

    private func ensureCurrentUserProfile(in db: Firestore, groupID: String) {
        let profile = makeCurrentUserProfile()
        db.collection("groups")
            .document(groupID)
            .collection("players")
            .document(currentUserID)
            .setData(profile.firestoreData, merge: true)
    }

    private func detachListeners() {
        groupsListener?.remove()
        groupsListener = nil
        detachGroupContentListeners()
    }

    private func detachGroupContentListeners() {
        playerListener?.remove()
        playerListener = nil
        betListener?.remove()
        betListener = nil
    }

    private func persistedActiveGroupID(for userID: String) -> String? {
        UserDefaults.standard.string(forKey: activeGroupStorageKey(for: userID))
    }

    private func persistActiveGroupID(_ groupID: String) {
        UserDefaults.standard.set(groupID, forKey: activeGroupStorageKey(for: currentUserID))
    }

    private func activeGroupStorageKey(for userID: String) -> String {
        "friendbet.activeGroup.\(userID)"
    }

    private func makeCurrentUserProfile() -> Player {
        let baseName = currentUserName.isEmpty ? "FriendBet Player" : currentUserName
        let handleSeed = baseName.lowercased().replacingOccurrences(of: " ", with: "")
        return Player(
            id: currentUserID,
            name: baseName,
            handle: "@\(String(handleSeed.prefix(16)))",
            avatar: String(baseName.prefix(1)),
            points: players.first(where: { $0.id == currentUserID })?.points ?? 980,
            wins: players.first(where: { $0.id == currentUserID })?.wins ?? 0,
            streak: players.first(where: { $0.id == currentUserID })?.streak ?? 0,
            accentHex: players.first(where: { $0.id == currentUserID })?.accentHex ?? "FF8C68"
        )
    }

    private func upsertLocalGroup(_ group: Group) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.insert(group, at: 0)
        }
    }

    private func friendlyFirestoreMessage(for error: Error, during action: String) -> String {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           let code = FirestoreErrorCode.Code(rawValue: nsError.code),
           code == .permissionDenied {
            return "Firebase blocked this action while trying to \(action). Update your Firestore rules for groups, invite codes, players, and bets."
        }

        return error.localizedDescription
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).compactMap { _ in alphabet.randomElement() })
    }

    private static let groupAccentPalette = ["FF8C68", "5FE7C4", "87B7FF", "D9A7FF", "F4C95D"]

    private static let sampleGroups: [Group] = [
        Group(
            id: "local-group",
            name: "Friday Picks",
            inviteCode: "FRIEND",
            ownerID: "local-marwan",
            accentHex: "87B7FF",
            memberIDs: ["local-marwan", "local-avery", "local-jordan", "local-sam", "local-taylor"],
            memberCount: 5,
            createdAt: Date()
        )
    ]

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
}

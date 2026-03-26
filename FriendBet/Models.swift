import Foundation
import SwiftUI
import FirebaseFirestore

enum BetCategory: String, CaseIterable, Identifiable, Codable {
    case sports = "Sports"
    case entertainment = "Entertainment"
    case money = "Money"
    case lifestyle = "Lifestyle"
    case custom = "Custom"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .sports: return "sportscourt.fill"
        case .entertainment: return "music.note.tv.fill"
        case .money: return "dollarsign.circle.fill"
        case .lifestyle: return "sparkles"
        case .custom: return "wand.and.stars"
        }
    }

    var tint: Color {
        switch self {
        case .sports: return Color(hex: "5FE7C4")
        case .entertainment: return Color(hex: "FF8C68")
        case .money: return Color(hex: "F4C95D")
        case .lifestyle: return Color(hex: "87B7FF")
        case .custom: return Color(hex: "D9A7FF")
        }
    }
}

enum BetStatus: String, CaseIterable, Identifiable, Codable {
    case active = "Active"
    case pending = "Pending"
    case settled = "Settled"

    var id: String { rawValue }
}

struct Player: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var handle: String
    var avatar: String
    var points: Int
    var wins: Int
    var streak: Int
    var accentHex: String

    var accent: Color { Color(hex: accentHex) }
    var initials: String {
        let pieces = name.split(separator: " ")
        return pieces.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

struct Group: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var inviteCode: String
    var ownerID: String
    var accentHex: String
    var memberIDs: [String]
    var memberCount: Int
    var createdAt: Date

    var accent: Color { Color(hex: accentHex) }
}

struct Bet: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var subtitle: String
    var category: BetCategory
    var stake: String
    var dueDate: Date
    var status: BetStatus
    var challengerID: String
    var opponentID: String
    var watchers: Int
    var comments: Int
    var confidence: Int
    var winnerID: String?
    var details: String
    var createdAt: Date
}

extension Player {
    static func fromSnapshot(_ document: DocumentSnapshot) -> Player? {
        guard let data = document.data() else { return nil }

        let name = data["name"] as? String ?? "FriendBet User"
        let handle = data["handle"] as? String ?? "@friend"
        let avatar = data["avatar"] as? String ?? String(name.prefix(1))
        let points = data["points"] as? Int ?? 0
        let wins = data["wins"] as? Int ?? 0
        let streak = data["streak"] as? Int ?? 0
        let accentHex = data["accentHex"] as? String ?? "87B7FF"

        return Player(
            id: document.documentID,
            name: name,
            handle: handle,
            avatar: avatar,
            points: points,
            wins: wins,
            streak: streak,
            accentHex: accentHex
        )
    }

    var firestoreData: [String: Any] {
        [
            "name": name,
            "handle": handle,
            "avatar": avatar,
            "points": points,
            "wins": wins,
            "streak": streak,
            "accentHex": accentHex
        ]
    }
}

extension Group {
    static func fromSnapshot(_ document: DocumentSnapshot) -> Group? {
        guard let data = document.data() else { return nil }
        guard
            let name = data["name"] as? String,
            let inviteCode = data["inviteCode"] as? String,
            let ownerID = data["ownerID"] as? String
        else {
            return nil
        }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let memberIDs = data["memberIDs"] as? [String] ?? []
        let memberCount = data["memberCount"] as? Int ?? memberIDs.count

        return Group(
            id: document.documentID,
            name: name,
            inviteCode: inviteCode,
            ownerID: ownerID,
            accentHex: data["accentHex"] as? String ?? "87B7FF",
            memberIDs: memberIDs,
            memberCount: memberCount,
            createdAt: createdAt
        )
    }

    var firestoreData: [String: Any] {
        [
            "name": name,
            "inviteCode": inviteCode,
            "ownerID": ownerID,
            "accentHex": accentHex,
            "memberIDs": memberIDs,
            "memberCount": memberCount,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

extension Bet {
    static func fromSnapshot(_ document: DocumentSnapshot) -> Bet? {
        guard let data = document.data() else { return nil }
        guard
            let title = data["title"] as? String,
            let subtitle = data["subtitle"] as? String,
            let categoryRaw = data["category"] as? String,
            let category = BetCategory(rawValue: categoryRaw),
            let stake = data["stake"] as? String,
            let dueTimestamp = data["dueDate"] as? Timestamp,
            let statusRaw = data["status"] as? String,
            let status = BetStatus(rawValue: statusRaw),
            let challengerID = data["challengerID"] as? String,
            let opponentID = data["opponentID"] as? String,
            let details = data["details"] as? String
        else {
            return nil
        }

        let createdAtTimestamp = data["createdAt"] as? Timestamp

        return Bet(
            id: document.documentID,
            title: title,
            subtitle: subtitle,
            category: category,
            stake: stake,
            dueDate: dueTimestamp.dateValue(),
            status: status,
            challengerID: challengerID,
            opponentID: opponentID,
            watchers: data["watchers"] as? Int ?? 0,
            comments: data["comments"] as? Int ?? 0,
            confidence: data["confidence"] as? Int ?? 50,
            winnerID: data["winnerID"] as? String,
            details: details,
            createdAt: createdAtTimestamp?.dateValue() ?? dueTimestamp.dateValue()
        )
    }

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "title": title,
            "subtitle": subtitle,
            "category": category.rawValue,
            "stake": stake,
            "dueDate": Timestamp(date: dueDate),
            "status": status.rawValue,
            "challengerID": challengerID,
            "opponentID": opponentID,
            "watchers": watchers,
            "comments": comments,
            "confidence": confidence,
            "details": details,
            "createdAt": Timestamp(date: createdAt)
        ]

        if let winnerID {
            data["winnerID"] = winnerID
        }

        return data
    }
}

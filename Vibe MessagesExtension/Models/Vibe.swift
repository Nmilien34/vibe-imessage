//
//  Vibe.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

struct Vibe: Codable, Identifiable, Equatable {
    let id: String
    let oderId: String?
    let userId: String
    let conversationId: String
    let type: VibeType
    let mediaUrl: String?
    let thumbnailUrl: String?
    let songData: SongData?
    let batteryLevel: Int?
    let mood: Mood?
    var poll: Poll?
    let isLocked: Bool
    var unlockedBy: [String]
    var reactions: [Reaction]
    var viewedBy: [String]
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date

}

extension Vibe {
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case oderId
        case userId
        case conversationId
        case type
        case mediaUrl
        case thumbnailUrl
        case songData
        case batteryLevel
        case mood
        case poll
        case isLocked
        case unlockedBy
        case reactions
        case viewedBy
        case expiresAt
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.oderId = try container.decodeIfPresent(String.self, forKey: .oderId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.conversationId = try container.decode(String.self, forKey: .conversationId)
        self.type = try container.decode(VibeType.self, forKey: .type)
        self.mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        self.thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        self.songData = try container.decodeIfPresent(SongData.self, forKey: .songData)
        self.batteryLevel = try container.decodeIfPresent(Int.self, forKey: .batteryLevel)
        self.mood = try container.decodeIfPresent(Mood.self, forKey: .mood)
        self.poll = try container.decodeIfPresent(Poll.self, forKey: .poll)
        self.isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        self.unlockedBy = try container.decodeIfPresent([String].self, forKey: .unlockedBy) ?? []
        self.reactions = try container.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        self.viewedBy = try container.decodeIfPresent([String].self, forKey: .viewedBy) ?? []
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    func isUnlocked(for userId: String) -> Bool {
        !isLocked || unlockedBy.contains(userId) || self.userId == userId
    }

    func hasViewed(_ userId: String) -> Bool {
        viewedBy.contains(userId)
    }

    func userReaction(_ userId: String) -> Reaction? {
        reactions.first { $0.userId == userId }
    }

    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSinceNow
    }

    var isExpired: Bool {
        timeRemaining <= 0
    }

    var timeRemainingFormatted: String {
        let remaining = max(0, timeRemaining)
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Create Vibe Request
struct CreateVibeRequest: Codable {
    let userId: String
    let conversationId: String
    let type: VibeType
    var mediaUrl: String?
    var thumbnailUrl: String?
    var songData: SongData?
    var batteryLevel: Int?
    var mood: Mood?
    var poll: CreatePollRequest?
    var isLocked: Bool = false
}

struct CreatePollRequest: Codable {
    let question: String
    let options: [String]
}

// MARK: - API Responses
struct VibesResponse: Codable {
    let vibes: [Vibe]
}

struct VibeResponse: Codable {
    let vibe: Vibe
}

struct StreakResponse: Codable {
    let streak: Streak
}

struct PresignedUrlResponse: Codable {
    let uploadUrl: String
    let publicUrl: String
    let key: String
}

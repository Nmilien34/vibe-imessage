//
//  Reaction.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

struct Reaction: Codable, Equatable, Identifiable {
    var id: String { oderId ?? userId }
    let oderId: String?
    let userId: String
    let emoji: String
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case oderId = "_id"
        case userId
        case emoji
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.oderId = try container.decodeIfPresent(String.self, forKey: .oderId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.emoji = try container.decode(String.self, forKey: .emoji)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    init(userId: String, emoji: String) {
        self.oderId = nil
        self.userId = userId
        self.emoji = emoji
        self.createdAt = Date()
    }

    static let availableEmojis = ["❤️", "🔥", "😂", "😮", "😢", "👏"]
}

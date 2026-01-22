//
//  Streak.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation

struct Streak: Codable, Equatable {
    let conversationId: String
    let currentStreak: Int
    let longestStreak: Int
    let lastPostDate: Date?
    let todayPosters: [String]

    var hasPostedToday: Bool {
        guard let lastPost = lastPostDate else { return false }
        return Calendar.current.isDateInToday(lastPost)
    }

    func userPostedToday(_ userId: String) -> Bool {
        todayPosters.contains(userId)
    }
}

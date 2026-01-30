//
//  NewsItem.swift
//  Vibe MessagesExtension
//
//  Created on 1/29/26.
//

import Foundation

struct NewsItem: Identifiable, Codable {
    let id: String
    let headline: String
    let imageUrl: String?
    let source: String
    let url: String
    let publishedAt: Date
    let vibeScore: Int
    let batch: String // "morning", "noon", "evening"
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case headline
        case imageUrl
        case source
        case url
        case publishedAt
        case vibeScore
        case batch
        case createdAt
    }
    
    var isJustIn: Bool {
        // Consider "Just In" if created within the last 2 hours
        Date().timeIntervalSince(createdAt) < 7200
    }
    
    var timeAgo: String {
        let interval = Date().timeIntervalSince(publishedAt)
        let hours = Int(interval / 3600)
        
        if hours < 1 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

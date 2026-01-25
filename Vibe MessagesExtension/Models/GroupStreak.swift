import Foundation

struct GroupStreak: Codable, Equatable {
    let chatId: String
    let currentStreak: Int
    let lastActiveDate: Date?
    
    // Compatibility with existing backend Streak structure
    enum CodingKeys: String, CodingKey {
        case chatId = "conversationId"
        case currentStreak
        case lastActiveDate = "lastPostDate"
    }
}

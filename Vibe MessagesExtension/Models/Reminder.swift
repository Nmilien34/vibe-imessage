import Foundation
import SwiftUI

enum ReminderType: String, Codable, CaseIterable {
    case birthday
    case hangout
    case event
    case custom

    var emoji: String {
        switch self {
        case .birthday: return "\u{1F382}"
        case .hangout: return "\u{1F389}"
        case .event: return "\u{1F3AB}"
        case .custom: return "\u{2728}"
        }
    }

    var displayName: String {
        switch self {
        case .birthday: return "Birthday"
        case .hangout: return "Hangout"
        case .event: return "Event"
        case .custom: return "Custom"
        }
    }

    var color: Color {
        switch self {
        case .birthday: return Color(red: 1.0, green: 0.3, blue: 0.5)
        case .hangout: return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .event: return Color(red: 0.6, green: 0.3, blue: 1.0)
        case .custom: return Color(red: 0.2, green: 0.5, blue: 1.0)
        }
    }

    var gradient: [Color] {
        switch self {
        case .birthday: return [Color(red: 1.0, green: 0.3, blue: 0.5), Color(red: 1.0, green: 0.5, blue: 0.7)]
        case .hangout: return [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.8, blue: 0.3)]
        case .event: return [Color(red: 0.6, green: 0.3, blue: 1.0), Color(red: 0.8, green: 0.4, blue: 1.0)]
        case .custom: return [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.7, blue: 1.0)]
        }
    }
}

struct Reminder: Codable, Identifiable {
    let id: String
    let chatId: String
    let userId: String
    let type: ReminderType
    let emoji: String
    let title: String
    let date: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case chatId, userId, type, emoji, title, date, createdAt
    }

    var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour], from: now, to: date)
        let days = components.day ?? 0
        let hours = components.hour ?? 0

        if days < 0 || (days == 0 && hours < 0) {
            return "Past"
        } else if days == 0 && hours < 24 {
            if hours <= 1 { return "Soon" }
            return "In \(hours)h"
        } else if days == 1 || (days == 0 && hours >= 0) {
            let tomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
            let reminderDay = calendar.startOfDay(for: date)
            if reminderDay == tomorrow { return "Tomorrow" }
            if days <= 1 { return "Tomorrow" }
        }

        if days <= 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: date)

            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "ha"
            let time = timeFormatter.string(from: date).lowercased()

            return "\(dayName) \(time)"
        }

        return "In \(days) days"
    }
}

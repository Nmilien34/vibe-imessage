//
//  VibeType.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import SwiftUI

enum VibeType: String, Codable, CaseIterable {
    case photo
    case video
    case song
    case battery
    case mood
    case poll
    case dailyDrop
    case tea
    case leak
    case sketch
    case eta
    case parlay

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .song: return "Song"
        case .battery: return "Battery"
        case .mood: return "Mood"
        case .poll: return "Poll"
        case .dailyDrop: return "Daily Drop"
        case .tea: return "Tea"
        case .leak: return "Leak"
        case .sketch: return "Sketch"
        case .eta: return "ETA"
        case .parlay: return "Parlay"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .song: return "music.note"
        case .battery: return "battery.100"
        case .mood: return "face.smiling"
        case .poll: return "chart.bar.fill"
        case .dailyDrop: return "die.face.5"
        case .tea: return "quote.bubble.fill"
        case .leak: return "shutter.releaser"
        case .sketch: return "hand.draw.fill"
        case .eta: return "location.fill"
        case .parlay: return "dollarsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .photo: return .blue
        case .video: return .pink
        case .song: return .green
        case .battery: return .yellow
        case .mood: return .purple
        case .poll: return .blue
        case .dailyDrop: return .black
        case .tea: return .brown
        case .leak: return .red
        case .sketch: return .orange
        case .eta: return .blue
        case .parlay: return Color(red: 1.0, green: 0.2, blue: 0.6)
        }
    }
}

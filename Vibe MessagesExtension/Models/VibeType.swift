//
//  VibeType.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import SwiftUI

enum VibeType: String, Codable, CaseIterable {
    case video
    case song
    case battery
    case mood
    case poll

    var displayName: String {
        switch self {
        case .video: return "Video"
        case .song: return "Song"
        case .battery: return "Battery"
        case .mood: return "Mood"
        case .poll: return "Poll"
        }
    }

    var icon: String {
        switch self {
        case .video: return "video.fill"
        case .song: return "music.note"
        case .battery: return "battery.100"
        case .mood: return "face.smiling"
        case .poll: return "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .video: return .pink
        case .song: return .green
        case .battery: return .yellow
        case .mood: return .purple
        case .poll: return .blue
        }
    }
}

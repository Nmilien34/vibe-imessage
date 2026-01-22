//
//  Mood.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import Foundation
import SwiftUI

struct Mood: Codable, Equatable {
    let emoji: String
    let text: String?

    static let presets: [(emoji: String, label: String)] = [
        ("😊", "Happy"),
        ("😴", "Tired"),
        ("🔥", "Hyped"),
        ("😢", "Sad"),
        ("😤", "Frustrated"),
        ("🥳", "Celebrating"),
        ("😎", "Cool"),
        ("🤔", "Thinking"),
        ("😍", "In Love"),
        ("🫠", "Melting"),
        ("💪", "Strong"),
        ("😌", "Peaceful")
    ]
}

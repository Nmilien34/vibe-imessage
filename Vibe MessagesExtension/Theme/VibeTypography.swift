//
//  VibeTypography.swift
//  Vibe MessagesExtension
//
//  Centralized typography scale using SF Pro Rounded.
//

import SwiftUI

enum VibeTypography {
    // MARK: - Display
    static let displayLarge = Font.system(size: 34, weight: .bold)
    static let displayMedium = Font.system(size: 28, weight: .bold)
    static let displaySmall = Font.system(size: 22, weight: .bold)

    // MARK: - Title
    static let titleLarge = Font.system(size: 20, weight: .semibold)
    static let titleMedium = Font.system(size: 17, weight: .semibold)
    static let titleSmall = Font.system(size: 15, weight: .semibold)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // MARK: - Caption
    static let captionLarge = Font.system(size: 12, weight: .medium)
    static let captionSmall = Font.system(size: 11, weight: .medium)

    // MARK: - Overline (section headers)
    static let overline = Font.system(size: 11, weight: .bold)

    // MARK: - Numeric (monospaced for counters/timers)
    static let numericLarge = Font.system(size: 34, weight: .bold, design: .monospaced).monospacedDigit()
    static let numericMedium = Font.system(size: 20, weight: .semibold, design: .monospaced).monospacedDigit()
    static let numericSmall = Font.system(size: 12, weight: .medium, design: .monospaced).monospacedDigit()
}

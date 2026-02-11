//
//  VibeTypography.swift
//  Vibe MessagesExtension
//
//  Centralized typography scale using SF Pro Rounded.
//

import SwiftUI

enum VibeTypography {
    // MARK: - Display
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
    static let displaySmall = Font.system(size: 22, weight: .bold, design: .rounded)

    // MARK: - Title
    static let titleLarge = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleMedium = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let titleSmall = Font.system(size: 15, weight: .semibold, design: .rounded)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .rounded)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .rounded)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .rounded)

    // MARK: - Caption
    static let captionLarge = Font.system(size: 12, weight: .medium, design: .rounded)
    static let captionSmall = Font.system(size: 11, weight: .medium, design: .rounded)

    // MARK: - Overline (section headers)
    static let overline = Font.system(size: 11, weight: .bold, design: .rounded)

    // MARK: - Numeric (monospaced for counters/timers)
    static let numericLarge = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
    static let numericMedium = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    static let numericSmall = Font.system(size: 12, weight: .medium, design: .rounded).monospacedDigit()
}

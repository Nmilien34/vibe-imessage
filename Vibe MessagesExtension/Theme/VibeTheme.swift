//
//  VibeTheme.swift
//  Vibe MessagesExtension
//
//  Centralized design tokens for the Vibe app.
//

import SwiftUI
import UIKit

enum VibeTheme {
    // MARK: - Brand Colors
    static let accent = Color(red: 1.0, green: 0.388, blue: 0.278) // #FF6347
    static let accentSecondary = Color(red: 1.0, green: 0.557, blue: 0.325) // #FF8E53
    static let accentCyan = Color(red: 0.353, green: 0.784, blue: 0.980) // #5AC8FA
    static let accentBlue = Color(UIColor.systemBlue)

    // MARK: - Semantic Backgrounds
    static let background = Color(UIColor.systemGroupedBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemBackground)

    // MARK: - Surface Elevation
    static let surfaceElevated = Color(UIColor.secondarySystemBackground)
    static let surfaceOverlay = Color(UIColor.tertiarySystemFill)

    // MARK: - Semantic Text
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Tinted Backgrounds (for bet type cards, stake states)
    static let warm = Color(red: 1.0, green: 0.39, blue: 0.28)           // #FF6347 tomato
    static let warmLight = Color(red: 1.0, green: 0.94, blue: 0.93)      // #FFF0ED
    static let accentLight = Color(red: 0.93, green: 0.93, blue: 0.98)   // #EEEDF9
    static let greenBg = Color(red: 0.91, green: 0.98, blue: 0.93)       // #E8F9ED
    static let redBg = Color(red: 1.0, green: 0.94, blue: 0.94)          // #FFF0EF
    static let textQuaternary = Color(UIColor.quaternaryLabel)

    // MARK: - Utility
    static let divider = Color(UIColor.separator).opacity(0.35)
    static let overlay = Color.black.opacity(0.3)

    // MARK: - Brand Gradient
    static let brandGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Feature Gradients
    static let auraGradient = LinearGradient(
        colors: [warm, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let teaGradient = LinearGradient(
        colors: [accentCyan, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let betGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.0, green: 0.6, blue: 0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Challenge Colors
    static let stakeYes = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    static let stakeNo = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30
    static let betAccent = Color(UIColor.systemBlue)
    static let challengeGradient = LinearGradient(
        colors: [warm, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Corner Radii
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 24
    static let radiusXL: CGFloat = 30
}

//
//  VibeTheme.swift
//  Vibe MessagesExtension
//
//  Centralized design tokens for the Vibe app.
//

import SwiftUI
import UIKit

enum VibeTheme {
    // MARK: - Brand Colors (adaptive via asset catalog)
    static let accent = Color("VibeAccent")
    static let accentSecondary = Color("VibeSecondary")
    static let accentCyan = Color("VibeCyan")
    static let accentBlue = Color("VibeBlue")

    // MARK: - Semantic Backgrounds
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let groupedBackground = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: - Surface Elevation (dark mode aware)
    static let surfaceElevated = Color(UIColor.tertiarySystemBackground)
    static let surfaceOverlay = Color(UIColor.systemGray6)

    // MARK: - Semantic Text
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Utility
    static let divider = Color(UIColor.separator)
    static let overlay = Color.black.opacity(0.4)

    // MARK: - Brand Gradient
    static let brandGradient = LinearGradient(
        colors: [accent, accentSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Feature Gradients
    static let auraGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let teaGradient = LinearGradient(
        colors: [Color(red: 0.72, green: 0.53, blue: 0.35), Color(red: 0.55, green: 0.35, blue: 0.17)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let betGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.0, green: 0.6, blue: 0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Challenge Colors
    static let stakeYes = Color(.systemGreen)
    static let stakeNo = Color(.systemRed)
    static let betAccent = Color(.systemIndigo)
    static let challengeGradient = LinearGradient(
        colors: [Color(.systemIndigo), Color(.systemPurple)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Corner Radii
    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 16
    static let radiusLarge: CGFloat = 24
    static let radiusXL: CGFloat = 30
}

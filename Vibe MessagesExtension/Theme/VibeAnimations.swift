//
//  VibeAnimations.swift
//  Vibe MessagesExtension
//
//  Animation presets and haptic feedback helpers.
//

import SwiftUI
import UIKit

// MARK: - Animation Presets

enum VibeAnimation {
    static let bouncy = Animation.spring(response: 0.35, dampingFraction: 0.6)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.9)
    static let gentle = Animation.easeInOut(duration: 0.3)

    static let cardAppear = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let sheetPresent = Animation.spring(response: 0.4, dampingFraction: 0.85)

    // Content transition presets
    static let defaultTransition = AnyTransition.asymmetric(
        insertion: .opacity.combined(with: .scale(scale: 0.95)),
        removal: .opacity
    )
    static let slideUp = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .opacity.combined(with: .scale(scale: 0.95))
    )
}

// MARK: - Haptic Feedback

enum VibeHaptic {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

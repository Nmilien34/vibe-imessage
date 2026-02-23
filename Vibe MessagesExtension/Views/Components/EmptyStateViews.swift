//
//  EmptyStateViews.swift
//  Vibe MessagesExtension
//
//  Reusable empty state components.
//

import SwiftUI

// MARK: - Generic Empty State

struct VibeEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: VibeSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(VibeTheme.textTertiary)

            VStack(spacing: VibeSpacing.xs) {
                Text(title)
                    .font(VibeTypography.titleMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                Text(subtitle)
                    .font(VibeTypography.bodySmall)
                    .foregroundColor(VibeTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button {
                    VibeHaptic.light()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(VibeTheme.accent)
                        .padding(.horizontal, VibeSpacing.xl)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(VibeTheme.accent.opacity(0.1))
                        .continuousCorner(VibeTheme.radiusMedium)
                }
                .buttonStyle(VibePressStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VibeSpacing.xxxl)
    }
}

// MARK: - Predefined Empty States

extension VibeEmptyState {
    static func noVibes(action: (() -> Void)? = nil) -> VibeEmptyState {
        VibeEmptyState(
            icon: "camera.fill",
            title: "No Vibes Yet",
            subtitle: "Be the first to share a vibe with the squad!",
            actionTitle: action != nil ? "Post a Vibe" : nil,
            action: action
        )
    }

    static func noBets(action: (() -> Void)? = nil) -> VibeEmptyState {
        VibeEmptyState(
            icon: "dice",
            title: "No Challenges Yet",
            subtitle: "Start a challenge and pull your friends in",
            actionTitle: action != nil ? "Start Challenge" : nil,
            action: action
        )
    }

    static func noTea(action: (() -> Void)? = nil) -> VibeEmptyState {
        VibeEmptyState(
            icon: "cup.and.saucer",
            title: "No Tea",
            subtitle: "Spill some tea and let the squad guess!",
            actionTitle: action != nil ? "Spill Tea" : nil,
            action: action
        )
    }

    static var noTransactions: VibeEmptyState {
        VibeEmptyState(
            icon: "clock.arrow.circlepath",
            title: "No Transactions",
            subtitle: "Your Aura history will appear here"
        )
    }

    static var noReminders: VibeEmptyState {
        VibeEmptyState(
            icon: "bell.slash",
            title: "No Reminders",
            subtitle: "Add reminders for the group"
        )
    }
}

// MARK: - Previews

#Preview("No Vibes") {
    VibeEmptyState.noVibes { }
}

#Preview("No Challenges") {
    VibeEmptyState.noBets()
}

#Preview("No Transactions") {
    VibeEmptyState.noTransactions
}

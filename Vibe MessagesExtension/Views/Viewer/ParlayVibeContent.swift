//
//  ParlayVibeContent.swift
//  Vibe MessagesExtension
//
//  Interactive viewer for Parlay (bet) vibes.
//

import SwiftUI

struct ParlayVibeContent: View {
    let vibe: Vibe
    @EnvironmentObject var appState: AppState

    private var parlay: Parlay? {
        vibe.parlay
    }

    private var isSender: Bool {
        vibe.userId == appState.userId
    }

    private var isOpponent: Bool {
        if let opponentId = parlay?.opponentId {
            return opponentId == appState.userId
        }
        return !isSender
    }

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color.black, Color(red: 0.1, green: 0, blue: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VibeTheme.accent.opacity(0.2), VibeTheme.accentSecondary.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Text("💸")
                        .font(.system(size: 50))
                }
                .padding(.top, VibeSpacing.xxxl)

                // Bet Question/Title
                VStack(spacing: VibeSpacing.sm) {
                    Text(parlay?.displayTitle ?? "Friendly Bet")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let amount = parlay?.displayAmount, !amount.isEmpty {
                        Text(amount)
                            .font(VibeTypography.displayLarge)
                            .foregroundColor(VibeTheme.accent)
                    }
                }

                // Status Section
                VStack(spacing: VibeSpacing.sm) {
                    if let status = parlay?.status {
                        statusBadge(for: status)
                    }

                    if let opponentName = parlay?.opponentName {
                        Text("vs \(opponentName)")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Action Buttons
                if parlay?.status == .pending && isOpponent {
                    VStack(spacing: VibeSpacing.lg) {
                        Button {
                            VibeHaptic.success()
                            Task {
                                await appState.respondToParlay(on: vibe, status: .accepted)
                            }
                        } label: {
                            Text("Accept Bet")
                                .font(VibeTypography.titleMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, VibeSpacing.lg)
                                .background(VibeTheme.brandGradient)
                                .continuousCorner(VibeTheme.radiusLarge)
                        }
                        .buttonStyle(VibePressStyle())

                        Button {
                            VibeHaptic.light()
                            Task {
                                await appState.respondToParlay(on: vibe, status: .declined)
                            }
                        } label: {
                            Text("Decline")
                                .font(VibeTypography.bodyMedium)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, VibeSpacing.sm)
                        }
                    }
                    .padding(.horizontal, VibeSpacing.xxl)
                    .padding(.bottom, VibeSpacing.xxxl)
                } else if parlay?.status == .accepted {
                    VStack(spacing: VibeSpacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .symbolEffect(.bounce)
                        Text("Bet is On!")
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 60)
                } else if parlay?.status == .declined {
                    VStack(spacing: VibeSpacing.sm) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red.opacity(0.7))
                        Text("Bet Declined")
                            .font(VibeTypography.titleMedium)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 60)
                } else {
                    Text("Waiting for \(parlay?.opponentName ?? "opponent")...")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 60)
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(for status: ParlayStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending: return .orange
            case .accepted: return .green
            case .declined: return .red
            case .settled: return .blue
            case .active: return .purple
            case .resolved: return .gray
            case .cancelled: return .gray
            }
        }()

        Text(status.rawValue.uppercased())
            .font(VibeTypography.overline)
            .foregroundColor(.white)
            .padding(.horizontal, VibeSpacing.sm)
            .padding(.vertical, VibeSpacing.xxxs)
            .background(color.opacity(0.3))
            .continuousCorner(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

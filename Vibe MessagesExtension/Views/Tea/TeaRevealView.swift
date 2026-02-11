//
//  TeaRevealView.swift
//  Vibe MessagesExtension
//
//  Animated tea reveal showing answer, winners, and payouts.
//

import SwiftUI

struct TeaRevealView: View {
    @EnvironmentObject var appState: AppState
    let tea: TeaSpill
    let revealResponse: TeaRevealResponse

    @State private var showAnswer = false
    @State private var showPayouts = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.72, green: 0.53, blue: 0.35), Color(red: 0.35, green: 0.20, blue: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.xxl) {
                    // Header
                    VStack(spacing: VibeSpacing.md) {
                        Text("The Tea Has Been Spilled")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2)
                            .textCase(.uppercase)

                        Text(tea.mysteryText)
                            .font(VibeTypography.titleLarge)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, VibeSpacing.xxxl + VibeSpacing.lg)

                    // Answer Reveal
                    if showAnswer {
                        VStack(spacing: VibeSpacing.md) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.yellow)
                                .symbolEffect(.bounce)

                            Text("The answer is...")
                                .font(VibeTypography.bodyMedium)
                                .foregroundColor(.white.opacity(0.7))

                            Text(revealResponse.tea.answer ?? "???")
                                .font(VibeTypography.displayLarge)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(VibeSpacing.lg)
                                .frame(maxWidth: .infinity)
                                .background(.white.opacity(0.15))
                                .continuousCorner(VibeTheme.radiusMedium)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Options Summary
                    if showAnswer {
                        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                            Text("OPTIONS")
                                .font(VibeTypography.overline)
                                .foregroundColor(.white.opacity(0.6))

                            ForEach(tea.options, id: \.self) { option in
                                let isCorrect = option == revealResponse.tea.answer
                                HStack(spacing: VibeSpacing.md) {
                                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundColor(isCorrect ? .green : .white.opacity(0.4))

                                    Text(option)
                                        .font(VibeTypography.titleSmall)
                                        .foregroundColor(isCorrect ? .white : .white.opacity(0.5))

                                    Spacer()

                                    if isCorrect {
                                        Text("CORRECT")
                                            .font(VibeTypography.overline)
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(VibeSpacing.sm)
                                .background(isCorrect ? Color.green.opacity(0.15) : .clear)
                                .continuousCorner(VibeTheme.radiusSmall)
                            }
                        }
                        .padding(VibeSpacing.lg)
                        .background(.white.opacity(0.1))
                        .continuousCorner(VibeTheme.radiusMedium)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Payouts
                    if showPayouts, let payouts = revealResponse.payouts, !payouts.isEmpty {
                        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                            Text("PAYOUTS")
                                .font(VibeTypography.overline)
                                .foregroundColor(.white.opacity(0.6))

                            ForEach(Array(payouts.enumerated()), id: \.offset) { _, payout in
                                HStack(spacing: VibeSpacing.md) {
                                    Image(systemName: payout.amount >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                        .foregroundColor(payout.amount >= 0 ? .green : .red)

                                    VStack(alignment: .leading, spacing: VibeSpacing.xxxs) {
                                        Text(appState.nameForUser(payout.userId))
                                            .font(VibeTypography.titleSmall)
                                            .foregroundColor(.white)

                                        Text(payout.type.replacingOccurrences(of: "_", with: " ").capitalized)
                                            .font(VibeTypography.captionSmall)
                                            .foregroundColor(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    Text(payout.amount >= 0 ? "+\(payout.amount)" : "\(payout.amount)")
                                        .font(VibeTypography.numericMedium)
                                        .foregroundColor(payout.amount >= 0 ? .green : .red)
                                }
                                .padding(VibeSpacing.sm)
                            }
                        }
                        .padding(VibeSpacing.lg)
                        .background(.white.opacity(0.1))
                        .continuousCorner(VibeTheme.radiusMedium)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Done Button
                    if showPayouts {
                        Button {
                            VibeHaptic.light()
                            appState.navigateToFeed()
                        } label: {
                            Text("Done")
                                .font(VibeTypography.titleMedium)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: VibeSpacing.minTouchTarget)
                                .background(.white.opacity(0.2))
                                .continuousCorner(VibeTheme.radiusMedium)
                        }
                        .buttonStyle(VibePressStyle())
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.bottom, VibeSpacing.xxxl)
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.smooth.delay(0.5)) {
                showAnswer = true
            }
            withAnimation(VibeAnimation.smooth.delay(1.5)) {
                showPayouts = true
            }
        }
    }
}

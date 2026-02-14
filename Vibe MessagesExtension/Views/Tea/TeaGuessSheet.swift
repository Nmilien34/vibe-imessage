//
//  TeaGuessSheet.swift
//  Vibe MessagesExtension
//
//  Bottom sheet for guessing on a Tea Spill.
//

import SwiftUI

struct TeaGuessSheet: View {
    @EnvironmentObject var appState: AppState
    let tea: TeaSpill

    @State private var selectedOption: String?
    @State private var wagerAmount: Int = 10
    @State private var isSubmitting = false
    @State private var guessResult: TeaGuess?
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.xl) {
                    // Handle
                    Capsule()
                        .fill(VibeTheme.textTertiary)
                        .frame(width: 36, height: 5)
                        .padding(.top, VibeSpacing.sm)

                    // Back
                    HStack {
                        Button {
                            VibeHaptic.light()
                            appState.navigateToFeed()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(VibeTheme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }

                    // Header
                    VStack(spacing: VibeSpacing.sm) {
                        Text("Guess the Tea")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(VibeTheme.textPrimary)

                        Text("Spill the tea if you think you know!")
                            .font(VibeTypography.bodyMedium)
                            .foregroundColor(VibeTheme.textSecondary)
                    }

                    // Mystery Text
                    VStack(spacing: VibeSpacing.sm) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.brown)

                        Text(tea.mysteryText)
                            .font(VibeTypography.titleLarge)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(VibeSpacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.xl)
                    .background(VibeTheme.teaGradient)
                    .continuousCorner(VibeTheme.radiusLarge)
                    .vibeShadow(.md)

                    // Options
                    VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                        Text("YOUR GUESS")
                            .vibeSectionHeader()

                        ForEach(tea.options, id: \.self) { option in
                            optionCard(option)
                        }
                    }

                    // Wager
                    VStack(spacing: VibeSpacing.sm) {
                        Text("WAGER")
                            .vibeSectionHeader()

                        HStack(spacing: VibeSpacing.xs) {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                            Text("\(wagerAmount) Aura")
                                .font(VibeTypography.numericMedium)
                                .foregroundColor(VibeTheme.textPrimary)
                                .contentTransition(.numericText())
                        }

                        Slider(value: Binding(
                            get: { Double(wagerAmount) },
                            set: { wagerAmount = Int($0) }
                        ), in: 5...Double(min(100, max(5, appState.auraBalance))), step: 5)
                        .tint(.brown)

                        Text("Balance: \(appState.auraBalance) Aura")
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(VibeTheme.textTertiary)
                    }
                    .padding(VibeSpacing.lg)
                    .vibeCard(radius: VibeTheme.radiusMedium)

                    // Timer
                    HStack(spacing: VibeSpacing.xs) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("Ends \(tea.deadline, style: .relative)")
                            .font(VibeTypography.captionSmall)
                    }
                    .foregroundColor(VibeTheme.textTertiary)

                    // Submit
                    Button {
                        VibeHaptic.medium()
                        Task { await submitGuess() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text(isSubmitting ? "Submitting..." : "Place Guess")
                        }
                        .vibeButton(.primary)
                    }
                    .buttonStyle(VibePressStyle())
                    .disabled(selectedOption == nil || isSubmitting || appState.auraBalance < wagerAmount)
                    .opacity(selectedOption == nil ? 0.5 : 1.0)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(VibeTypography.captionSmall)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.bottom, VibeSpacing.xxxl)
            }

            // Success overlay
            if showSuccess {
                successOverlay
            }
        }
    }

    // MARK: - Option Card

    private func optionCard(_ option: String) -> some View {
        Button {
            VibeHaptic.selection()
            withAnimation(VibeAnimation.snappy) {
                selectedOption = option
            }
        } label: {
            HStack(spacing: VibeSpacing.md) {
                Image(systemName: selectedOption == option ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedOption == option ? .brown : VibeTheme.textTertiary)

                Text(option)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(VibeTheme.textPrimary)

                Spacer()
            }
            .padding(VibeSpacing.md)
            .background(selectedOption == option ? Color.brown.opacity(0.1) : .clear)
            .vibeCard(radius: VibeTheme.radiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                    .stroke(selectedOption == option ? Color.brown : VibeTheme.divider, lineWidth: selectedOption == option ? 2 : 1)
            )
        }
        .buttonStyle(VibePressStyle())
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: VibeSpacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Guess Placed!")
                    .font(VibeTypography.displaySmall)
                    .foregroundColor(.white)

                if let result = guessResult {
                    Text("Wagered \(result.amount) Aura on \"\(result.guess)\"")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Button {
                    VibeHaptic.light()
                    appState.navigateToFeed()
                } label: {
                    Text("Done")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.xxl)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(.ultraThinMaterial)
                        .continuousCorner(VibeTheme.radiusMedium)
                }
                .buttonStyle(VibePressStyle())
            }
        }
        .transition(.opacity)
    }

    // MARK: - Submit

    private func submitGuess() async {
        guard let option = selectedOption else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            let result = try await appState.guessTeaSpill(teaId: tea.teaId, guess: option, amount: wagerAmount)
            guessResult = result
            VibeHaptic.success()
            withAnimation(VibeAnimation.bouncy) {
                showSuccess = true
            }
        } catch {
            errorMessage = error.localizedDescription
            VibeHaptic.error()
        }
        isSubmitting = false
    }
}

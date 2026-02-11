import SwiftUI

struct DailyDropComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var currentPromptIndex = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var isShuffling = false

    let prompts = [
        "Show us your fridge",
        "Last picture in your gallery",
        "Recent screenshot",
        "Your current POV",
        "What you're eating right now",
        "Your workspace setup",
        "The view out your window",
        "Your current fit check"
    ]

    var body: some View {
        VStack(spacing: VibeSpacing.xxl) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: VibeTheme.radiusXL, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 280, height: 280)
                    .vibeShadow(.xl)

                VStack(spacing: VibeSpacing.md) {
                    Text("🎲")
                        .font(.system(size: 60))
                        .rotationEffect(.degrees(isShuffling ? 360 : 0))
                        .animation(isShuffling ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: isShuffling)

                    Text(prompts[currentPromptIndex])
                        .font(VibeTypography.displaySmall)
                        .foregroundColor(VibeTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(3)
                        .padding(.horizontal, VibeSpacing.xl)
                        .id(currentPromptIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .frame(width: 280, height: 280)
            }
            .offset(x: shakeOffset)

            VStack(spacing: VibeSpacing.md) {
                Button {
                    shuffle()
                } label: {
                    HStack(spacing: VibeSpacing.xs) {
                        Image(systemName: "dice.fill")
                        Text("Shuffle")
                            .font(VibeTypography.titleSmall)
                    }
                    .foregroundColor(VibeTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: VibeSpacing.minTouchTarget)
                    .background(.ultraThinMaterial)
                    .continuousCorner(VibeTheme.radiusMedium)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xxxl)

                Button {
                    VibeHaptic.success()
                    acceptChallenge()
                } label: {
                    Text("Send Challenge")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xxxl)
            }

            Spacer()
        }
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }

    private func shuffle() {
        guard !isShuffling else { return }
        isShuffling = true
        VibeHaptic.heavy()

        withAnimation(.default.repeatCount(5, autoreverses: true).speed(2)) {
            shakeOffset = 10
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
            currentPromptIndex = Int.random(in: 0..<prompts.count)
            isShuffling = false
            VibeHaptic.medium()
        }
    }

    private func acceptChallenge() {
        let prompt = prompts[currentPromptIndex]
        Task {
            do {
                let vibe = try await appState.createVibe(
                    type: .dailyDrop,
                    textStatus: prompt,
                    isLocked: isLocked
                )
                appState.sendVibeMessage(
                    vibeId: vibe.id,
                    isLocked: isLocked,
                    vibeType: .dailyDrop,
                    contextText: prompt
                )
                appState.dismissComposer()
            } catch {
                print("Error sending challenge: \(error)")
            }
        }
    }
}

#Preview {
    DailyDropComposerView(isLocked: false)
        .environmentObject(AppState())
}

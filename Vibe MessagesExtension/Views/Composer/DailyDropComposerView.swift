import SwiftUI

struct DailyDropComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var currentPromptIndex = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var isShuffling = false
    
    let prompts = [
        "Show us your fridge 🧊",
        "Last picture in your gallery 🖼️",
        "Recent screenshot 📱",
        "Your current POV 👀",
        "What you're eating right now 🍕",
        "Your workspace setup 💻",
        "The view out your window 🪟",
        "Your current fit check 👟"
    ]
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Dice / Prompt Card
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.black)
                        .frame(width: 280, height: 280)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 16) {
                        Text("🎲")
                            .font(.system(size: 60))
                            .rotationEffect(.degrees(isShuffling ? 360 : 0))
                            .animation(isShuffling ? .linear(duration: 0.5).repeatForever(autoreverses: false) : .default, value: isShuffling)
                        
                        Text(prompts[currentPromptIndex])
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(3)
                            .padding(.horizontal, 24)
                            .id(currentPromptIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    .frame(width: 280, height: 280)
                }
                .offset(x: shakeOffset)
            }
            
            VStack(spacing: 16) {
                // Shuffle Button
                Button {
                    shuffle()
                } label: {
                    HStack {
                        Image(systemName: "dice.fill")
                        Text("Shuffle")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray2))
                    .cornerRadius(16)
                }
                .padding(.horizontal, 40)
                
                // Accept Button
                Button {
                    acceptChallenge()
                } label: {
                    Text("Send Challenge")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func shuffle() {
        guard !isShuffling else { return }
        isShuffling = true
        
        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        
        // Shake Animation
        withAnimation(.default.repeatCount(5, autoreverses: true).speed(2)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shakeOffset = 0
            currentPromptIndex = Int.random(in: 0..<prompts.count)
            isShuffling = false
            generator.impactOccurred()
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

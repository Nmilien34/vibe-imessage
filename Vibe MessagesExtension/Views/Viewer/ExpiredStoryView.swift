import SwiftUI

struct ExpiredStoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            VibeTheme.background
                .ignoresSafeArea()

            VStack(spacing: VibeSpacing.xxl) {
                ZStack {
                    Circle()
                        .fill(VibeTheme.surfaceOverlay)
                        .frame(width: 120, height: 120)

                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundColor(VibeTheme.textTertiary)
                }

                VStack(spacing: VibeSpacing.sm) {
                    Text("This story has expired")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)

                    Text("Vibes only last for 24 hours to keep things fresh.")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VibeSpacing.xxxl)
                }

                Button {
                    VibeHaptic.light()
                    appState.navigateToFeed()
                } label: {
                    Text("Back to Feed")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xxxl)
                .padding(.top, VibeSpacing.lg)
            }
            .padding()
        }
    }
}

#Preview {
    ExpiredStoryView()
        .environmentObject(AppState())
}

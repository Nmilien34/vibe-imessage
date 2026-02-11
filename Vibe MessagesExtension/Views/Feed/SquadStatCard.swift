import SwiftUI

struct SquadStatCard<Center: View, Footer: View>: View {
    let title: String
    let icon: String // Emoji
    let accentColor: Color
    @ViewBuilder let centerContent: Center
    @ViewBuilder let footerContent: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            // Top Row: Icon and Title
            HStack(alignment: .top) {
                Text(icon)
                    .font(.system(size: 20))
                Spacer()
            }

            Spacer()

            // Center Content
            HStack {
                Spacer()
                centerContent
                Spacer()
            }

            Spacer()

            // Footer
            HStack {
                Spacer()
                footerContent
                Spacer()
            }
        }
        .padding(VibeSpacing.md)
        .frame(width: 110, height: 130)
        .background(VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .vibeShadow(.sm)
    }
}

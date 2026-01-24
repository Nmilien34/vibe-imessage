import SwiftUI

struct SquadStatCard<Center: View, Footer: View>: View {
    let title: String
    let icon: String // Emoji
    let accentColor: Color
    @ViewBuilder let centerContent: Center
    @ViewBuilder let footerContent: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(12)
        .frame(width: 110, height: 130)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

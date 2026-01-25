import SwiftUI

struct ExpiredStoryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Requirement: Gray background
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Requirement: Icon (Clock or crossed-out play button)
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 8) {
                    // Requirement: Text
                    Text("This story has expired")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Vibes only last for 24 hours to keep things fresh.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                Button {
                    appState.navigateToFeed()
                } label: {
                    Text("Back to Feed")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)
            }
            .padding()
        }
    }
}

#Preview {
    ExpiredStoryView()
        .environmentObject(AppState())
}

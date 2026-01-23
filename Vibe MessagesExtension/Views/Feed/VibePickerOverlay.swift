import SwiftUI

struct VibePickerOverlay: View {
    @EnvironmentObject var appState: AppState
    @Binding var isPresented: Bool
    
    // Scale animation state
    @State private var isAnimating = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background - tap to dismiss
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isAnimating = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPresented = false
                    }
                }
            
            // Picker Card
            if isAnimating {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a Vibe")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            // Video
                            PickerItem(title: "Video", icon: "video.fill", color: .pink) {
                                select(.video)
                            }
                            
                            // Photo
                            PickerItem(title: "Photo", icon: "camera.fill", color: .blue) {
                                select(.photo)
                            }
                            
                            // POV (Video + Locked)
                            PickerItem(title: "POV", icon: "eye.fill", color: .teal) {
                                select(.video, locked: true)
                            }

                            // Battery
                            PickerItem(title: "Battery", icon: "battery.100", color: .yellow) {
                                select(.battery)
                            }
                            
                            // Mood
                            PickerItem(title: "Mood", icon: "face.smiling", color: .purple) {
                                select(.mood)
                            }
                            
                            // Poll
                            PickerItem(title: "Poll", icon: "chart.bar.fill", color: .blue) {
                                select(.poll)
                            }
                            
                            // Dashboard (More)
                            PickerItem(title: "More", icon: "grid", color: .gray) {
                                dismiss()
                                appState.navigateToComposer() // Go to full dashboard
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
                .background(Material.regular)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 16)
                .padding(.bottom, 20) // Lift up from bottom
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    private func select(_ type: VibeType, locked: Bool = false) {
        // Close picker
        withAnimation {
            isAnimating = false
        }
        
        // Wait for animation then navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
            // We need to pass locked state too. 
            // Currently AppState.navigateToComposer only takes type.
            // I'll need to update AppState or handle locking in ComposerView via a temporary state if I can't change signature easily.
            // But wait, AppState uses `createVibe` which takes `isLocked`.
            // For navigation, `ComposerView` looks at `appState.selectedVibeType`.
            // `ComposerView` internal state `isLocked` is private.
            // I should update AppState to hold `initialLockedState` or similar, OR update ComposerView to read it from somewhere.
            // For now, I will modify AppState to accept isLocked in navigateToComposer.
            // Pass locked state to AppState
             appState.navigateToComposer(type: type, isLocked: locked)
        }
    }
    
    private func dismiss() {
        withAnimation {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

struct PickerItem: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

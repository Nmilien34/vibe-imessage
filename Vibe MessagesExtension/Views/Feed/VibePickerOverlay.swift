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
                    withAnimation(VibeAnimation.snappy) {
                        isAnimating = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isPresented = false
                    }
                }

            // Picker Card
            if isAnimating {
                VStack(alignment: .leading, spacing: VibeSpacing.lg) {
                    Text("Choose a Vibe")
                        .font(VibeTypography.titleSmall)
                        .padding(.horizontal)
                        .padding(.top, VibeSpacing.lg)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VibeSpacing.lg) {
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
                                appState.navigateToComposer()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, VibeSpacing.xxl)
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous))
                .vibeShadow(.lg)
                .padding(.horizontal, VibeSpacing.lg)
                .padding(.bottom, VibeSpacing.lg)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.bouncy) {
                isAnimating = true
            }
        }
    }

    private func select(_ type: VibeType, locked: Bool = false) {
        VibeHaptic.selection()
        withAnimation {
            isAnimating = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
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
            VStack(spacing: VibeSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textPrimary)
            }
        }
        .buttonStyle(VibePressStyle())
    }
}

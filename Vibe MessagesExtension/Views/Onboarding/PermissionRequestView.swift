import SwiftUI
import AVFoundation

struct PermissionRequestView: View {
    @EnvironmentObject var appState: AppState

    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var audioStatus: AVAuthorizationStatus = .notDetermined
    @State private var isVisible = false

    var body: some View {
        VStack(spacing: VibeSpacing.xxxl) {
            Spacer()

            VStack(spacing: VibeSpacing.md) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(VibeTheme.brandGradient)

                Text("One last thing...")
                    .font(VibeTypography.displayMedium)
                    .foregroundColor(VibeTheme.textPrimary)

                Text("Vibe needs access to your camera and audio to share your vibes with the squad.")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VibeSpacing.xxxl)
            }
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)

            VStack(spacing: VibeSpacing.lg) {
                PermissionRow(
                    title: "Camera",
                    icon: "camera.fill",
                    status: cameraStatus,
                    action: requestCamera
                )

                PermissionRow(
                    title: "Microphone",
                    icon: "mic.fill",
                    status: audioStatus,
                    action: requestAudio
                )
            }
            .padding(.horizontal, VibeSpacing.xxxl)
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 30)

            Spacer()

            VStack(spacing: VibeSpacing.md) {
                Button {
                    VibeHaptic.success()
                    appState.setPermissionsGranted()
                } label: {
                    Text("Continue to Vibe")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .disabled(!allGranted)
                .opacity(allGranted ? 1.0 : 0.5)
                .padding(.horizontal, VibeSpacing.xxxl)

                #if DEBUG
                Button {
                    VibeHaptic.light()
                    appState.setPermissionsGranted()
                } label: {
                    Text("Dev: Skip Permissions")
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(VibeTheme.textTertiary)
                }
                #endif
            }

            Spacer()
        }
        .onAppear {
            updateStatuses()
            withAnimation(VibeAnimation.smooth.delay(0.2)) {
                isVisible = true
            }
        }
    }

    private var allGranted: Bool {
        cameraStatus == .authorized && audioStatus == .authorized
    }

    private func updateStatuses() {
        let newCameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let newAudioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if newCameraStatus != cameraStatus { cameraStatus = newCameraStatus }
        if newAudioStatus != audioStatus { audioStatus = newAudioStatus }
    }

    private func requestCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    updateStatuses()
                }
            }
        } else {
            updateStatuses()
        }
    }

    private func requestAudio() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    updateStatuses()
                }
            }
        } else {
            updateStatuses()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let status: AVAuthorizationStatus
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(VibeTheme.accent)
                .frame(width: VibeSpacing.minTouchTarget)

            Text(title)
                .font(VibeTypography.titleMedium)
                .foregroundColor(VibeTheme.textPrimary)

            Spacer()

            if status == .authorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 24))
            } else {
                Button(action: {
                    VibeHaptic.medium()
                    action()
                }) {
                    Text("Allow")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.md)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(VibeTheme.accent)
                        .continuousCorner(VibeTheme.radiusSmall)
                }
                .buttonStyle(VibePressStyle())
            }
        }
        .padding(VibeSpacing.md)
        .vibeGlassCard(radius: VibeTheme.radiusMedium)
    }
}

#Preview {
    PermissionRequestView()
        .environmentObject(AppState())
}

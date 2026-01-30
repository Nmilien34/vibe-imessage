import SwiftUI
import AVFoundation

struct PermissionRequestView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var cameraStatus: AVAuthorizationStatus = .notDetermined
    @State private var audioStatus: AVAuthorizationStatus = .notDetermined
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("One last thing...")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                
                Text("Vibe needs access to your camera and audio to share your vibes with the squad.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 20) {
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
            .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button {
                    appState.setPermissionsGranted()
                } label: {
                    Text("Continue to Vibe")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            allGranted ? Color.blue : Color.gray
                        )
                        .cornerRadius(20)
                        .padding(.horizontal, 40)
                }
                .disabled(!allGranted)
                .opacity(allGranted ? 1.0 : 0.6)
                
                #if DEBUG
                Button {
                    appState.setPermissionsGranted()
                } label: {
                    Text("Dev: Skip Permissions")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
                #endif
            }
            
            Spacer()
        }
        .onAppear(perform: updateStatuses)
    }
    
    private var allGranted: Bool {
        // In a real app, we want both. In some environments, we might want to accept .authorized or .prohibited/etc if we can't change it.
        // For Vibe, we really need .authorized for the core features.
        cameraStatus == .authorized && audioStatus == .authorized
    }
    
    private func updateStatuses() {
        let newCameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let newAudioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        // Only update if changed to avoid unnecessary re-renders
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
            // If already denied/restricted, the user must go to settings.
            // But for now, just refresh to show the current state.
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
                .font(.title2)
                .frame(width: 40)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            if status == .authorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Button(action: action) {
                    Text("Allow")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    PermissionRequestView()
        .environmentObject(AppState())
}

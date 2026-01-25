//
//  CreatorCameraView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import PhotosUI

enum CameraMode: String, CaseIterable, Identifiable {
    case normal = "NORMAL"
    case locked = "LOCKED"
    case loop = "LOOP"
    
    var id: String { self.rawValue }
}

struct CreatorCameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CameraViewModel()
    
    // Config
    var initialMode: CameraMode = .normal
    
    // State
    @State private var selectedMode: CameraMode
    @State private var showPrompter = false
    @State private var promptText = "Show us your fridge."
    @State private var timerString = "00:00 / 00:15"
    @State private var isBoomerang = false
    
    // Bindings to parent (VideoComposerView)
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var mediaData: Data?
    @Binding var thumbnail: UIImage?
    
    init(initialLocked: Bool = false, selectedItem: Binding<PhotosPickerItem?>, mediaData: Binding<Data?>, thumbnail: Binding<UIImage?>) {
        _selectedMode = State(initialValue: initialLocked ? .locked : .normal)
        _selectedItem = selectedItem
        _mediaData = mediaData
        _thumbnail = thumbnail
    }
    
    var body: some View {
        ZStack {
            // Layer 1: Camera Feed
            if let session = viewModel.session {
                CameraPreview(session: session)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 80))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            if viewModel.isUnauthorized {
                                Text("Camera access required")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                    )
            }
            
            // Layer 2: UI Overlay
            VStack {
                // A. Header
                headerView
                
                Spacer()
                
                // B. Prompter (Center)
                if showPrompter {
                    Text(promptText)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // C. Footer controls
                footerView
            }
            .padding(.top, 44)
            .padding(.bottom, 20)
            .opacity(viewModel.isRecording ? 0.3 : 1.0) // Dim UI while recording
        }
        .onAppear {
            viewModel.checkPermissions()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .onChange(of: viewModel.recordedVideo) { _, newValue in
            if let video = newValue {
                Task {
                    // Load data and thumbnail
                    if let data = try? Data(contentsOf: video.url) {
                        self.mediaData = data
                        self.thumbnail = await MessageService.shared.generateThumbnail(from: video.url)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Close Button
            Button {
                appState.dismissComposer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .shadow(radius: 4)
            
            Spacer()
            
            // Timer Capsule
            if viewModel.isRecording {
                Text(String(format: "%02d:%02d / 00:15", Int(viewModel.recordingTime) / 60, Int(viewModel.recordingTime) % 60))
                    .font(.system(.subheadline, design: .rounded))
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // Camera Tools (Flash & Flip)
            VStack(spacing: 12) {
                Button {
                    viewModel.flipCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Button {
                    isBoomerang.toggle()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "infinity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isBoomerang ? .yellow : .white)
                        .frame(width: 44, height: 44)
                        .background(isBoomerang ? Color.yellow.opacity(0.2) : Color.black.opacity(0.3))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(isBoomerang ? Color.yellow : Color.clear, lineWidth: 2)
                        )
                }
            }
            .shadow(radius: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: 24) {
            // 1. Mode Selector
            HStack(spacing: 24) {
                ForEach(CameraMode.allCases) { mode in
                    Button {
                        withAnimation(.spring()) {
                            selectedMode = mode
                        }
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Text(mode.rawValue)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(selectedMode == mode ? .bold : .medium)
                                .foregroundColor(.white)
                                .opacity(selectedMode == mode ? 1.0 : 0.5)
                            
                            if selectedMode == mode {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 4, height: 4)
                                    .shadow(color: .yellow, radius: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .shadow(radius: 4)
            .opacity(viewModel.isRecording ? 0 : 1)
            
            // 2. Action Row
            HStack(spacing: 40) {
                // Left: Dice / Prompts
                Button {
                    withAnimation {
                        showPrompter.toggle()
                        promptText = "Show us your fridge."
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "die.face.5")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .opacity(viewModel.isRecording ? 0 : 1)
                
                // Center: Shutter Button
                ZStack {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: viewModel.isRecording ? [.red, .orange] : [.red, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: viewModel.isRecording ? 70 : 60, height: viewModel.isRecording ? 70 : 60)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
                        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                            if pressing {
                                viewModel.startRecording()
                            } else {
                                viewModel.stopRecording()
                            }
                        }) { }
                    
                    if viewModel.isRecording {
                        Circle()
                            .trim(from: 0, to: viewModel.recordingTime / 15.0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 76, height: 76)
                            .rotationEffect(.degrees(-90))
                    }
                }
                
                // Right: Gallery
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.videos, .images])) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(radius: 4)
                }
                .disabled(viewModel.isRecording)
                .opacity(viewModel.isRecording ? 0 : 1)
            }
            .padding(.bottom, 20)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

#Preview {
    CreatorCameraView(selectedItem: .constant(nil), mediaData: .constant(nil), thumbnail: .constant(nil))
        .environmentObject(AppState())
}

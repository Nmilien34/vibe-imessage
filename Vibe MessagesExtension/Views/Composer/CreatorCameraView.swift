//
//  CreatorCameraView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

enum CameraMode: String, CaseIterable, Identifiable {
    case normal = "NORMAL"
    case photo = "PHOTO"
    case boomerang = "BOOMERANG"
    case real = "REAL"
    case locked = "LOCKED"

    var id: String { self.rawValue }
}

struct CreatorCameraView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CameraViewModel()

    // State
    @State private var selectedMode: CameraMode
    @State private var showPrompter = false
    @State private var promptText = "Show us your fridge."
    @State private var pulseScale: CGFloat = 1.0

    // Music
    @State private var showMusicPicker = false
    @State private var selectedSong: SongData?

    // Text overlay (pre-camera, applied in editor)
    @State private var showTextInput = false
    @State private var pendingOverlayText = ""

    // Flash
    @State private var isFlashOn = false

    // Timer (countdown before recording)
    @State private var countdownActive = false
    @State private var countdownValue = 0
    @State private var selectedTimerDuration = 0 // 0 = off, 3, 10
    @State private var showTimerMenu = false

    // Filters
    @State private var showFiltersSheet = false
    @State private var selectedFilter: String? = nil

    // Bindings to parent (VideoComposerView)
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var mediaData: Data?       // used for photos only (small JPEG)
    @Binding var videoURL: URL?         // used for videos — avoids loading full Data into memory
    @Binding var thumbnail: UIImage?
    @Binding var mediaType: VibeType

    // Pass song selection back to parent
    var onSongSelected: ((SongData?) -> Void)?
    var onClose: (() -> Void)?
    // Called when user finishes entering pre-record overlay text
    var onTextCommitted: ((String) -> Void)?

    init(
        initialLocked: Bool = false,
        selectedItem: Binding<PhotosPickerItem?>,
        mediaData: Binding<Data?>,
        videoURL: Binding<URL?>,
        thumbnail: Binding<UIImage?>,
        mediaType: Binding<VibeType>,
        onClose: (() -> Void)? = nil,
        onTextCommitted: ((String) -> Void)? = nil
    ) {
        _selectedMode = State(initialValue: initialLocked ? .locked : .normal)
        _selectedItem = selectedItem
        _mediaData = mediaData
        _videoURL = videoURL
        _thumbnail = thumbnail
        _mediaType = mediaType
        self.onClose = onClose
        self.onTextCommitted = onTextCommitted
    }

    var body: some View {
        ZStack {
            // Layer 1: Camera Feed
            cameraFeedLayer

            // Layer 2: Filter overlay
            if let filter = selectedFilter {
                filterOverlay(for: filter)
            }

            // Layer 2b: Bottom gradient for legibility
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
            }
            .edgesIgnoringSafeArea(.bottom)

            // Layer 3: Main UI (hidden during countdown)
            if !countdownActive {
                VStack {
                    topBar
                        .opacity(viewModel.isRecording ? 0.3 : 1.0)

                    Spacer()

                    // Center Prompter
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

                    // Sidebar tools (right)
                    HStack(alignment: .bottom) {
                        Spacer()
                        sidebarTools
                            .opacity(viewModel.isRecording ? 0.3 : 1.0)
                    }

                    // Mode slider
                    modeSlider
                        .opacity(viewModel.isRecording ? 0.3 : 1.0)

                    // Shutter row
                    shutterRow
                        .padding(.bottom, VibeSpacing.xl)
                }
                .padding(.top, VibeSpacing.sm)
            }

            // Layer 4: Recording timer (top center)
            if viewModel.isRecording || viewModel.isProcessingBoomerang {
                VStack {
                    Text(viewModel.isProcessingBoomerang
                         ? "Creating boomerang…"
                         : String(format: "%02d:%02d / 00:%02d",
                                  Int(viewModel.recordingTime) / 60,
                                  Int(viewModel.recordingTime) % 60,
                                  selectedMode == .boomerang ? 2 : 15))
                        .font(VibeTypography.bodyMedium)
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.lg)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                        .padding(.top, 60)
                    Spacer()
                }
            }

            // Layer 5a: REAL mode camera-switch / front-capture hint
            if viewModel.realCapturePhase == .capturedBack || viewModel.realCapturePhase == .capturingFront {
                VStack {
                    Text(viewModel.realCapturePhase == .capturingFront ? "📸 Smile!" : "📱 Switching cameras…")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, 70)
                    Spacer()
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.realCapturePhase == .capturingFront)
            }

            // Layer 5b: Boomerang processing overlay
            if viewModel.isProcessingBoomerang {
                ZStack {
                    Color.black.opacity(0.65).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                        Text("Creating boomerang…")
                            .foregroundColor(.white)
                            .font(VibeTypography.titleSmall)
                    }
                }
                .transition(.opacity)
            }

            // Layer 5: Countdown overlay
            if countdownActive {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                Text("\(countdownValue)")
                    .font(.system(size: 120, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .transition(.scale)
            }

            // Layer 6: Text input overlay
            if showTextInput {
                textInputOverlay
            }
        }
        .onAppear {
            viewModel.reset()
            viewModel.checkPermissions()
        }
        .onDisappear {
            viewModel.stopSession()
            if isFlashOn {
                viewModel.toggleFlash(false)
                isFlashOn = false
            }
        }
        .onChange(of: viewModel.recordedVideo) { _, newValue in
            if let video = newValue {
                Task {
                    if selectedMode == .boomerang {
                        // Process into a forward+reverse loop.
                        // Store the URL directly — do NOT load into Data (crashes iMessage ext).
                        if let boomerangURL = await viewModel.processBoomerang(from: video.url) {
                            self.videoURL = boomerangURL
                            self.thumbnail = await MessageService.shared.generateThumbnail(from: boomerangURL)
                            self.mediaType = .video
                            // boomerangURL lifecycle: parent clears videoURL on reset → iOS temp cleanup
                        }
                    } else {
                        // Store URL directly — no Data(contentsOf:) which loads 30-80 MB into memory
                        self.videoURL = video.url
                        self.thumbnail = await MessageService.shared.generateThumbnail(from: video.url)
                        self.mediaType = .video
                    }
                }
            }
        }
        .onChange(of: viewModel.capturedPhoto) { _, newValue in
            if let image = newValue {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    self.mediaData = data
                    self.thumbnail = image
                    self.mediaType = .photo
                }
            }
        }
        .onChange(of: selectedSong) { _, newValue in
            onSongSelected?(newValue)
        }
        .sheet(isPresented: $showMusicPicker) {
            MusicPickerView(selectedSong: $selectedSong)
        }
        .sheet(isPresented: $showFiltersSheet) {
            filterSelectionSheet
        }
    }

    // MARK: - Camera Feed

    private var cameraFeedLayer: some View {
        Group {
            if let session = viewModel.session {
                CameraPreview(session: session)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Color.black
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack(spacing: VibeSpacing.lg) {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 80))
                                .foregroundColor(VibeTheme.textTertiary)
                            if viewModel.isUnauthorized {
                                Text("Camera access required")
                                    .foregroundColor(.white)
                                    .font(VibeTypography.captionLarge)
                            }
                        }
                    )
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .top) {
            // Close
            Button {
                VibeHaptic.light()
                if let onClose {
                    onClose()
                } else {
                    appState.dismissComposer()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // Music Pill
            Button {
                showMusicPicker = true
            } label: {
                HStack(spacing: VibeSpacing.xs) {
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                    if let song = selectedSong {
                        Text("\(song.artist) - \(song.title)")
                            .font(VibeTypography.captionLarge)
                            .lineLimit(1)
                            .frame(maxWidth: 180)
                    } else {
                        Text("Pick a song")
                            .font(VibeTypography.captionLarge)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, VibeSpacing.lg)
                .padding(.vertical, VibeSpacing.sm)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            Spacer()

            // Balance spacer
            Color.clear.frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
        }
        .padding(.horizontal, VibeSpacing.md)
    }

    // MARK: - Sidebar Tools

    private var sidebarTools: some View {
        VStack(spacing: VibeSpacing.xl) {
            // Flip
            CameraToolButton(icon: "arrow.triangle.2.circlepath", label: "Flip") {
                viewModel.flipCamera()
                VibeHaptic.light()
            }

            // Text
            CameraToolButton(icon: nil, label: "Text", customContent: AnyView(
                Text("Aa")
                    .font(.system(size: 20, weight: .heavy, design: .serif))
                    .frame(width: 32, height: 32)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .foregroundColor(.white)
            )) {
                showTextInput = true
            }

            // Music
            CameraToolButton(
                icon: "music.quarternote.3",
                label: "Music",
                isActive: selectedSong != nil
            ) {
                showMusicPicker = true
            }

            // Sound
            CameraToolButton(
                icon: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: viewModel.isMuted ? "Muted" : "Sound",
                isActive: !viewModel.isMuted
            ) {
                viewModel.toggleMute(!viewModel.isMuted)
                VibeHaptic.light()
            }

            // Flash
            CameraToolButton(
                icon: isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                label: "Flash",
                isActive: isFlashOn
            ) {
                isFlashOn.toggle()
                viewModel.toggleFlash(isFlashOn)
                VibeHaptic.light()
            }

            // Timer
            CameraToolButton(
                icon: "timer",
                label: selectedTimerDuration > 0 ? "\(selectedTimerDuration)s" : "Timer",
                isActive: selectedTimerDuration > 0
            ) {
                showTimerMenu.toggle()
            }
            .confirmationDialog("Self Timer", isPresented: $showTimerMenu) {
                Button("Off") { selectedTimerDuration = 0 }
                Button("3 seconds") { selectedTimerDuration = 3 }
                Button("10 seconds") { selectedTimerDuration = 10 }
                Button("Cancel", role: .cancel) { }
            }

            // Filters
            CameraToolButton(
                icon: "wand.and.stars",
                label: "Filters",
                isActive: selectedFilter != nil
            ) {
                showFiltersSheet = true
            }
        }
        .padding(.trailing, VibeSpacing.sm)
        .padding(.bottom, VibeSpacing.xl)
    }

    // MARK: - Mode Slider

    private var modeSlider: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VibeSpacing.xxl) {
                ForEach(CameraMode.allCases) { mode in
                    Text(mode.rawValue)
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(selectedMode == mode ? .yellow : .white.opacity(0.7))
                        .shadow(color: .black.opacity(0.5), radius: 1)
                        .onTapGesture {
                            withAnimation(VibeAnimation.snappy) {
                                selectedMode = mode
                            }
                            VibeHaptic.selection()
                        }
                }
            }
            .padding(.horizontal, UIScreen.main.bounds.width / 2 - 40)
        }
        .padding(.bottom, VibeSpacing.xl)
    }

    // MARK: - Shutter Row

    private var shutterRow: some View {
        HStack(spacing: 50) {
            // Left: Gallery
            PhotosPicker(selection: $selectedItem, matching: .any(of: [.videos, .images])) {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .background(Color.black.opacity(0.3))
                    .continuousCorner(10)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            }
            .disabled(viewModel.isRecording)
            .opacity(viewModel.isRecording ? 0 : 1)

            // Center: Shutter
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 5)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.2), radius: 4)

                if selectedMode == .photo || selectedMode == .real {
                    // Photo shutter: solid white circle, no recording ring
                    Circle()
                        .fill(Color.white)
                        .frame(width: 66, height: 66)
                        .scaleEffect(pulseScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pulseScale)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                pulseScale = 1.05
                            }
                        }
                        .onTapGesture {
                            VibeHaptic.medium()
                            if selectedMode == .photo {
                                viewModel.takePhoto()
                            } else {
                                // REAL: start dual capture if idle
                                guard viewModel.realCapturePhase == .idle else { return }
                                viewModel.startRealCapture()
                            }
                        }
                } else {
                    // Video / boomerang shutter
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: viewModel.isRecording
                                    ? [.red, .orange]
                                    : [Color(red: 1.0, green: 0.2, blue: 0.6), .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(
                            width: viewModel.isRecording ? 70 : 66,
                            height: viewModel.isRecording ? 70 : 66
                        )
                        .scaleEffect(viewModel.isRecording ? 1.0 : pulseScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isRecording)
                        .onAppear {
                            if !viewModel.isRecording {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                    pulseScale = 1.1
                                }
                            }
                        }
                        .onTapGesture {
                            VibeHaptic.medium()
                            if viewModel.isRecording {
                                viewModel.stopRecording()
                            } else {
                                viewModel.maxDuration = selectedMode == .boomerang ? 2.0 : 15.0
                                beginRecording()
                            }
                        }

                    if viewModel.isRecording {
                        let maxSec = selectedMode == .boomerang ? 2.0 : 15.0
                        Circle()
                            .trim(from: 0, to: viewModel.recordingTime / maxSec)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }

            // Right: Dice
            Button {
                withAnimation(VibeAnimation.bouncy) {
                    showPrompter.toggle()
                    let prompts = [
                        "Show us your fridge.",
                        "Last pic in your gallery.",
                        "Your current POV.",
                        "What you're eating rn.",
                        "Your workspace setup.",
                        "Your recent screenshot.",
                        "Your current fit check."
                    ]
                    promptText = prompts.randomElement() ?? "Show us your fridge."
                }
                VibeHaptic.medium()
            } label: {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .background(Circle().fill(.ultraThinMaterial))
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .overlay(
                        Image(systemName: "dice.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
            }
            .opacity(viewModel.isRecording ? 0 : 1)
        }
    }

    // MARK: - Text Input Overlay

    @FocusState private var isTextFocused: Bool

    private var textInputOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    commitText()
                }

            VStack {
                Spacer()
                TextField("Add text...", text: $pendingOverlayText)
                    .focused($isTextFocused)
                    .font(VibeTypography.displaySmall)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .onSubmit {
                        commitText()
                    }
                Spacer()
            }
        }
        .onAppear {
            isTextFocused = true
        }
    }

    private func commitText() {
        showTextInput = false
        isTextFocused = false
        onTextCommitted?(pendingOverlayText)
    }

    // MARK: - Filter Overlay

    @ViewBuilder
    private func filterOverlay(for filter: String) -> some View {
        switch filter {
        case "Warm":
            Color.orange.opacity(0.15)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
        case "Cool":
            Color.blue.opacity(0.12)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
        case "B&W":
            Color.white.opacity(0.0)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
                .saturation(0)
        case "Vibez":
            LinearGradient(colors: [Color.pink.opacity(0.1), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    // MARK: - Filter Sheet

    private var filterSelectionSheet: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: VibeSpacing.lg) {
                    FilterOption(name: "None", color: .gray, isSelected: selectedFilter == nil) {
                        VibeHaptic.selection()
                        selectedFilter = nil
                        showFiltersSheet = false
                    }
                    FilterOption(name: "Warm", color: .orange, isSelected: selectedFilter == "Warm") {
                        VibeHaptic.selection()
                        selectedFilter = "Warm"
                        showFiltersSheet = false
                    }
                    FilterOption(name: "Cool", color: .blue, isSelected: selectedFilter == "Cool") {
                        VibeHaptic.selection()
                        selectedFilter = "Cool"
                        showFiltersSheet = false
                    }
                    FilterOption(name: "B&W", color: .white, isSelected: selectedFilter == "B&W") {
                        VibeHaptic.selection()
                        selectedFilter = "B&W"
                        showFiltersSheet = false
                    }
                    FilterOption(name: "Vibez", color: .purple, isSelected: selectedFilter == "Vibez") {
                        VibeHaptic.selection()
                        selectedFilter = "Vibez"
                        showFiltersSheet = false
                    }
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showFiltersSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Timer / Recording

    private func beginRecording() {
        if selectedTimerDuration > 0 && !countdownActive {
            countdownActive = true
            countdownValue = selectedTimerDuration
            VibeHaptic.heavy()
            startCountdown()
        } else if !countdownActive {
            viewModel.startRecording()
        }
    }

    private func startCountdown() {
        guard countdownValue > 0 else {
            countdownActive = false
            viewModel.startRecording()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(VibeAnimation.bouncy) {
                countdownValue -= 1
            }
            VibeHaptic.medium()

            if countdownValue > 0 {
                startCountdown()
            } else {
                countdownActive = false
                viewModel.startRecording()
            }
        }
    }
}

// MARK: - Filter Option Card

struct FilterOption: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: VibeSpacing.sm) {
                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                    .fill(color.opacity(0.3))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                            .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 3)
                    )
                    .overlay(
                        Text(name)
                            .font(VibeTypography.captionLarge)
                            .foregroundColor(.primary)
                    )
            }
        }
        .buttonStyle(VibePressStyle())
    }
}

// MARK: - Camera Tool Button

struct CameraToolButton: View {
    var icon: String?
    var label: String
    var isActive: Bool = false
    var customContent: AnyView? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VibeSpacing.xxxs) {
                if let custom = customContent {
                    custom
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }

                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .shadow(color: .black.opacity(0.3), radius: 1)
            }
            .foregroundColor(isActive ? .yellow : .white)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = VideoPreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewView = uiView as? VideoPreviewUIView {
            previewView.videoPreviewLayer.session = session
        }
    }
}

private class VideoPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview {
    CreatorCameraView(selectedItem: .constant(nil), mediaData: .constant(nil), videoURL: .constant(nil), thumbnail: .constant(nil), mediaType: .constant(.video))
        .environmentObject(AppState())
}

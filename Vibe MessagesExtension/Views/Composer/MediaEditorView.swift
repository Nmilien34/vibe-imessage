import SwiftUI
import AVFoundation
import Combine

struct MediaEditorView: View {
    @EnvironmentObject var appState: AppState

    let mediaType: VibeType
    let mediaData: Data?    // nil for videos; contains JPEG data for photos
    let videoURL: URL?      // set for videos; nil for photos — AVPlayer uses URL directly
    let thumbnail: UIImage?
    let isLocked: Bool
    let initialOverlayText: String
    let onShare: (String?, SongData?) async -> Void
    let onCancel: () -> Void

    @State private var overlayText: String
    @State private var isEditingText = false
    @State private var textPosition: CGPoint = .zero
    @State private var selectedSong: SongData?
    @State private var showMusicSearch = false
    @State private var musicUnavailable = false

    @FocusState private var isTextFieldFocused: Bool

    @StateObject private var playerController = PlayerController()

    init(
        mediaType: VibeType,
        mediaData: Data? = nil,
        videoURL: URL? = nil,
        thumbnail: UIImage?,
        isLocked: Bool,
        initialOverlayText: String = "",
        onShare: @escaping (String?, SongData?) async -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.mediaType = mediaType
        self.mediaData = mediaData
        self.videoURL = videoURL
        self.thumbnail = thumbnail
        self.isLocked = isLocked
        self.initialOverlayText = initialOverlayText
        self.onShare = onShare
        self.onCancel = onCancel
        _overlayText = State(initialValue: initialOverlayText)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Background Media Preview
                mediaPreview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                        if overlayText.isEmpty {
                            isEditingText = true
                            isTextFieldFocused = true
                        }
                    }

                // Text Overlay
                if !overlayText.isEmpty && !isEditingText {
                    Text(overlayText)
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.lg)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(.ultraThinMaterial)
                        .continuousCorner(VibeTheme.radiusMedium)
                        .position(textPosition == .zero
                            ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            : textPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    textPosition = value.location
                                }
                        )
                        .onTapGesture {
                            isEditingText = true
                            isTextFieldFocused = true
                        }
                }

                // Text Input Mode
                if isEditingText {
                    Color.black.opacity(0.6).ignoresSafeArea()
                        .onTapGesture {
                            isEditingText = false
                            isTextFieldFocused = false
                        }

                    VStack {
                        Spacer()
                        TextField("Type something...", text: $overlayText)
                            .focused($isTextFieldFocused)
                            .font(VibeTypography.displaySmall)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                            .onSubmit {
                                isEditingText = false
                                isTextFieldFocused = false
                            }
                        Spacer()
                    }
                }

                // UI Controls
                VStack {
                    header
                    Spacer()
                    footer
                }
                .opacity(isEditingText ? 0 : 1)
            }
            .onAppear {
                if textPosition == .zero {
                    textPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
        .task(id: videoURL?.path ?? "") {
            // Re-init player when video URL changes (handles re-picks from gallery)
            if mediaType == .video, let url = videoURL {
                await playerController.setup(with: url)
            }
        }
        .alert("Music Unavailable", isPresented: $musicUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Apple Music integration isn't available right now. You can still add a text caption.")
        }
        .sheet(isPresented: $showMusicSearch) {
            MusicSelectorView(selectedSong: $selectedSong)
        }
    }

    private var mediaPreview: some View {
        Group {
            if mediaType == .video {
                if let player = playerController.player {
                    AVPlayerLayerView(player: player)
                        .ignoresSafeArea()
                } else {
                    // Show thumbnail while player is loading instead of black
                    ZStack {
                        Color.black
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                                .opacity(0.5)
                        }
                        ProgressView()
                            .tint(.white)
                    }
                    .ignoresSafeArea()
                }
            } else {
                let photoImage = thumbnail ?? mediaData.flatMap { UIImage(data: $0) }
                if let img = photoImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            HStack(spacing: VibeSpacing.lg) {
                Button {
                    isEditingText = true
                    isTextFieldFocused = true
                } label: {
                    Image(systemName: "textformat")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button {
                    do {
                        // Guard: MusicKit crashes in iMessage extensions without entitlement.
                        // Attempt to present — if it fails the alert fires instead.
                        if #available(iOS 15.0, *) {
                            showMusicSearch = true
                        } else {
                            musicUnavailable = true
                        }
                    }
                } label: {
                    Image(systemName: selectedSong != nil ? "music.note.list" : "music.note")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(selectedSong != nil ? .green : .white)
                        .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding(VibeSpacing.md)
    }

    private var footer: some View {
        VStack(spacing: VibeSpacing.lg) {
            if let song = selectedSong {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.green)
                    Text("\(song.title) - \(song.artist)")
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Button {
                        selectedSong = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, VibeSpacing.sm)
                .padding(.vertical, VibeSpacing.xs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            Button {
                VibeHaptic.success()
                Task {
                    await onShare(overlayText.isEmpty ? nil : overlayText, selectedSong)
                }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Share Vibe")
                }
                .font(VibeTypography.titleMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget + 12)
                .background(VibeTheme.brandGradient)
                .continuousCorner(VibeTheme.radiusLarge)
                .padding(.horizontal, VibeSpacing.xxxl)
            }
            .buttonStyle(VibePressStyle())
        }
        .padding(.bottom, VibeSpacing.xxl)
    }
}

// MARK: - PlayerController

class PlayerController: ObservableObject {
    @Published var player: AVPlayer?
    private var observer: Any?
    private var tempURL: URL?

    /// Sets up (or replaces) the player with the given video URL.
    /// Uses the URL directly for AVPlayer — no temp file write needed.
    @MainActor
    func setup(with videoURL: URL) async {
        // Tear down existing player first.
        player?.pause()
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
        // tempURL is no longer used (URL-based approach), but clean up if it exists from an old session.
        if let old = tempURL {
            try? FileManager.default.removeItem(at: old)
            tempURL = nil
        }
        player = nil

        let item = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.actionAtItemEnd = .none

        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero)
            newPlayer?.play()
        }
        self.observer = obs

        self.player = newPlayer
        newPlayer.play()
    }

    deinit {
        // AVPlayer and NotificationCenter are thread-safe to call from deinit.
        player?.pause()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AVPlayerLayerView
// A UIView subclass that owns an AVPlayerLayer and resizes it properly via layoutSubviews.

final class PlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        backgroundColor = .black
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // Player is owned by PlayerUIView; layout handled in layoutSubviews.
    }
}

// MARK: - MusicSelectorView

struct MusicSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: SongData?

    var body: some View {
        MusicPickerView(selectedSong: $selectedSong)
    }
}

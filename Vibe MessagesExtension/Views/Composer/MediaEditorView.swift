import SwiftUI
import AVFoundation
import Combine

struct MediaEditorView: View {
    @EnvironmentObject var appState: AppState

    let mediaType: VibeType
    let mediaData: Data
    let thumbnail: UIImage?
    let isLocked: Bool
    let onShare: (String?, SongData?) async -> Void
    let onCancel: () -> Void

    @State private var overlayText: String = ""
    @State private var isEditingText = false
    @State private var textPosition: CGPoint = .zero
    @State private var selectedSong: SongData?
    @State private var showMusicSearch = false

    @FocusState private var isTextFieldFocused: Bool

    @StateObject private var playerController = PlayerController()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Background Media Preview
                mediaPreview
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
                        .position(textPosition == .zero ? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2) : textPosition)
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
                textPosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                if mediaType == .video {
                    playerController.setup(with: mediaData)
                }
            }
        }
        .sheet(isPresented: $showMusicSearch) {
            MusicSelectorView(selectedSong: $selectedSong)
        }
    }

    private var mediaPreview: some View {
        Group {
            if mediaType == .video {
                if let player = playerController.player {
                    VideoPlayerView(player: player)
                } else {
                    Color.black
                }
            } else {
                if let uiImage = (thumbnail ?? UIImage(data: mediaData)) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .background(Color.black)
                } else {
                    Color.red.overlay(Text("No Image Data").foregroundColor(.white))
                }
            }
        }
        .ignoresSafeArea()
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
                    showMusicSearch = true
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

class PlayerController: ObservableObject {
    @Published var player: AVPlayer?
    private var observer: Any?
    private var tempURL: URL?

    func setup(with data: Data) {
        if player != nil { return }
        print("MediaEditor: Setting up player with data (\(data.count) bytes)")

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        self.tempURL = url

        do {
            try data.write(to: url)
            let player = AVPlayer(url: url)
            player.actionAtItemEnd = .none

            self.observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }

            self.player = player
            player.play()
        } catch {
            print("PlayerController Error: \(error)")
        }
    }

    deinit {
        player?.pause()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        uiView.layer.sublayers?.forEach { layer in
            if let playerLayer = layer as? AVPlayerLayer {
                playerLayer.frame = uiView.bounds
            }
        }
        CATransaction.commit()
    }
}

struct MusicSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedSong: SongData?

    var body: some View {
        MusicPickerView(selectedSong: $selectedSong)
    }
}

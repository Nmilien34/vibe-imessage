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
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
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
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.bold)
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
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                Button {
                    isEditingText = true
                    isTextFieldFocused = true
                } label: {
                    Image(systemName: "textformat")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Button {
                    showMusicSearch = true
                } label: {
                    Image(systemName: selectedSong != nil ? "music.note.list" : "music.note")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(selectedSong != nil ? .green : .white)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
    }
    
    private var footer: some View {
        VStack(spacing: 16) {
            if let song = selectedSong {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundColor(.green)
                    Text("\(song.title) - \(song.artist)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Button {
                        selectedSong = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            
            Button {
                Task {
                    await onShare(overlayText.isEmpty ? nil : overlayText, selectedSong)
                }
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Share Vibe")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .padding(.horizontal, 40)
            }
        }
        .padding(.bottom, 30)
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
        // Ensure layer matches view bounds on every update
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

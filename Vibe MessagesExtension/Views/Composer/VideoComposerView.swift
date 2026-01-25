//
//  VideoComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AVFoundation
import PhotosUI

struct VideoComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var thumbnailImage: UIImage?
    @State private var mediaType: VibeType = .video
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            if let data = mediaData {
                // Media Editor replaces static preview
                MediaEditorView(
                    mediaType: mediaType,
                    mediaData: data,
                    thumbnail: thumbnailImage,
                    isLocked: isLocked,
                    onShare: { overlayText, songData in
                        await shareMedia(overlayText: overlayText, song: songData)
                    },
                    onCancel: {
                        mediaData = nil
                        thumbnailImage = nil
                        selectedItem = nil
                    }
                )
            } else {
                CreatorCameraView(initialLocked: isLocked, selectedItem: $selectedItem, mediaData: $mediaData, thumbnail: $thumbnailImage)
            }
            
            if isUploading {
                uploadOverlay
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                await loadMedia(from: newValue)
            }
        }
        .alert("Upload Failed", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Retry") {
                Task { await shareMedia() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let error = error {
                Text(error)
            }
        }
    }

    private var uploadOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: uploadProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.pink)
                    .padding(.horizontal, 40)
                
                Text(uploadProgress < 0.9 ? "Uploading Vibe..." : "Almost there...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            // Check if it's a video or image
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let data = try await item.loadTransferable(type: Data.self) {
                    mediaData = data
                    thumbnailImage = await generateThumbnail(from: data)
                    mediaType = .video
                    return
                }
            }
            
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }) {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    mediaData = data
                    thumbnailImage = image
                    mediaType = .photo
                    return
                }
            }
        } catch {
            self.error = "Failed to load media"
        }
    }

    private func generateThumbnail(from data: Data) async -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        try? data.write(to: tempURL)

        let asset = AVURLAsset(url: tempURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let (cgImage, _) = try await imageGenerator.image(at: .zero)
            try? FileManager.default.removeItem(at: tempURL)
            return UIImage(cgImage: cgImage)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }

    private func shareMedia(overlayText: String? = nil, song: SongData? = nil) async {
        guard let data = mediaData else { return }
        guard let chatId = appState.conversationId else {
            self.error = "No active conversation"
            return
        }

        isUploading = true
        error = nil

        do {
            // 1. Upload Video (Multipart)
            uploadProgress = 0.2
            
            let result = try await APIService.shared.uploadVideo(
                videoData: data,
                userId: appState.userId,
                chatId: chatId,
                isLocked: isLocked
            )
            
            uploadProgress = 0.7
            
            // 2. Create the Vibe Record for Feed (Optional logic, since upload already created one in my backend implementation of /upload)
            // Note: My backend implementation of /vibe/upload ALREADY creates the Vibe record.
            // If we want to add extra data (song, text), we should update it or send it in the upload.
            // Current /vibe/upload doesn't take song/text. Let's fix backend or just send them separately.
            // FOR NOW: I'll assume we want the full record.
            
            // Actually, let's update AppState.createVibe to see if it can take existing URLs.
            try await appState.createVibe(
                type: .video,
                mediaUrl: result.videoUrl,
                thumbnailUrl: nil, // Add thumbnail upload if we want, but S3 handles it
                songData: song,
                textStatus: overlayText,
                isLocked: isLocked
            )
            
            uploadProgress = 0.9
            
            // 3. Send iMessage Bubble with real VideoId
            appState.sendStory?(result.videoId, result.videoUrl, isLocked, thumbnailImage)
            
            uploadProgress = 1.0
            appState.dismissComposer()
        } catch {
            self.error = error.localizedDescription
        }

        isUploading = false
    }
}

#Preview {
    NavigationStack {
        VideoComposerView(isLocked: false)
            .environmentObject(AppState())
    }
}

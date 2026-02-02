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
    @State private var showUploadError = false
    @State private var pendingOverlayText: String?
    @State private var pendingSong: SongData?

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
                CreatorCameraView(initialLocked: isLocked, selectedItem: $selectedItem, mediaData: $mediaData, thumbnail: $thumbnailImage, mediaType: $mediaType)
            }
            
            if isUploading {
                uploadOverlay
            }

            // Upload Error Overlay
            if showUploadError {
                Color.black.opacity(0.6).ignoresSafeArea()
                UploadErrorView(
                    error: error,
                    onRetry: {
                        showUploadError = false
                        Task {
                            await shareMedia(overlayText: pendingOverlayText, song: pendingSong)
                        }
                    },
                    onCancel: {
                        showUploadError = false
                        error = nil
                    }
                )
                .padding()
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                await loadMedia(from: newValue)
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
        // Use currentChatId (our distributed ID system) instead of conversationId
        guard let chatId = appState.currentChatId ?? appState.conversationId else {
            self.error = "No active conversation"
            self.showUploadError = true
            return
        }

        // Store pending values for retry
        pendingOverlayText = overlayText
        pendingSong = song

        isUploading = true
        error = nil
        showUploadError = false

        do {
            // 1. Upload Video (Multipart)
            uploadProgress = 0.2

            let result = try await APIService.shared.uploadMedia(
                mediaData: data,
                userId: appState.userId,
                chatId: chatId,
                isLocked: isLocked,
                isVideo: mediaType == .video
            )

            uploadProgress = 0.7

            // 2. Create the Vibe Record for Feed
            // Note: The upload endpoint creates a basic vibe, but we create another
            // with full metadata (song, text overlay) for the feed
            let vibe = try await appState.createVibe(
                type: mediaType,
                mediaUrl: result.videoUrl,
                mediaKey: result.videoKey,
                songData: song,
                textStatus: overlayText,
                isLocked: isLocked
            )

            uploadProgress = 0.9

            // 3. Send iMessage Bubble with the vibe ID
            appState.sendVibeMessage(
                vibeId: vibe.id,
                mediaUrl: result.videoUrl,
                isLocked: isLocked,
                thumbnail: thumbnailImage,
                vibeType: mediaType,
                contextText: overlayText
            )

            uploadProgress = 1.0

            // Clear pending values on success
            pendingOverlayText = nil
            pendingSong = nil

            appState.dismissComposer()
        } catch {
            self.error = error.localizedDescription
            self.showUploadError = true
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

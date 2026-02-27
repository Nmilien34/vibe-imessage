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
    @State private var mediaData: Data?     // photos only (JPEG)
    @State private var videoURL: URL?       // videos only (URL avoids loading into memory)
    @State private var thumbnailImage: UIImage?
    @State private var mediaType: VibeType = .video
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var error: String?
    @State private var showUploadError = false
    @State private var pendingOverlayText: String?
    @State private var pendingSong: SongData?
    @State private var cameraText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if mediaData != nil || videoURL != nil {
                // Media Editor replaces static preview
                MediaEditorView(
                    mediaType: mediaType,
                    mediaData: mediaData,
                    videoURL: videoURL,
                    thumbnail: thumbnailImage,
                    isLocked: isLocked,
                    initialOverlayText: cameraText,
                    onShare: { overlayText, songData in
                        await shareMedia(overlayText: overlayText, song: songData)
                    },
                    onCancel: {
                        mediaData = nil
                        videoURL = nil
                        thumbnailImage = nil
                        selectedItem = nil
                        cameraText = ""
                    }
                )
            } else {
                CreatorCameraView(
                    initialLocked: isLocked,
                    selectedItem: $selectedItem,
                    mediaData: $mediaData,
                    videoURL: $videoURL,
                    thumbnail: $thumbnailImage,
                    mediaType: $mediaType,
                    onTextCommitted: { text in
                        cameraText = text
                    }
                )
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
                    .font(VibeTypography.titleSmall)
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            // Check if it's a video or image
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Write to temp file immediately so data can be freed from memory.
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + ".mov")
                    try data.write(to: tempURL)
                    videoURL = tempURL
                    thumbnailImage = await generateThumbnail(from: tempURL)
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

    private func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let (cgImage, _) = try await imageGenerator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    private func shareMedia(overlayText: String? = nil, song: SongData? = nil) async {
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
            // 1. Determine upload source URL — video uses URL directly, photo writes to temp file
            uploadProgress = 0.2

            let isVideoUpload = mediaType == .video
            let uploadSourceURL: URL

            if isVideoUpload {
                guard let url = videoURL else {
                    throw NSError(domain: "VideoComposerView", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "No video to upload."])
                }
                uploadSourceURL = url
            } else {
                guard let data = mediaData else {
                    throw NSError(domain: "VideoComposerView", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "No photo to upload."])
                }
                let photoTempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".jpg")
                try data.write(to: photoTempURL)
                uploadSourceURL = photoTempURL
            }

            let result = try await APIService.shared.uploadMedia(
                mediaURL: uploadSourceURL,
                userId: appState.userId,
                chatId: chatId,
                isLocked: isLocked,
                isVideo: isVideoUpload
            )

            // Clean up photo temp file if we created one
            if !isVideoUpload {
                try? FileManager.default.removeItem(at: uploadSourceURL)
            }

            uploadProgress = 0.6

            // 2. Upload thumbnail if we have one (non-blocking — failure is silent)
            var thumbnailUrl: String? = nil
            var thumbnailKey: String? = nil
            if mediaType == .photo {
                // Photo is its own thumbnail
                thumbnailUrl = result.videoUrl
                thumbnailKey = result.videoKey
            } else if let thumbImage = thumbnailImage,
                      let jpegData = thumbImage.jpegData(compressionQuality: 0.7) {
                let thumbResult = try? await VibeService.shared.uploadMediaWithKey(
                    data: jpegData,
                    fileType: "jpg",
                    folder: "thumbnails"
                )
                thumbnailUrl = thumbResult?.url
                thumbnailKey = thumbResult?.key
            }

            uploadProgress = 0.7

            // 3. Create the Vibe Record for Feed
            // Note: The upload endpoint creates a basic vibe, but we create another
            // with full metadata (song, text overlay) for the feed
            let vibe = try await appState.createVibe(
                type: mediaType,
                mediaUrl: result.videoUrl,
                mediaKey: result.videoKey,
                thumbnailUrl: thumbnailUrl,
                thumbnailKey: thumbnailKey,
                songData: song,
                textStatus: overlayText,
                isLocked: isLocked
            )

            uploadProgress = 0.9

            // 4. Send iMessage Bubble with the vibe ID
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

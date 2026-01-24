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
                // Creator Camera View (Default State)
                CreatorCameraView(initialLocked: isLocked, selectedItem: $selectedItem)
            }
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                await loadMedia(from: newValue)
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

        isUploading = true
        error = nil

        do {
            // Upload media
            uploadProgress = 0.3
            let fileType = mediaType == .video ? "mp4" : "jpg"
            let folder = mediaType == .video ? "vibes" : "photos"
            
            let mediaUrl = try await VibeService.shared.uploadMedia(
                data: data,
                fileType: fileType,
                folder: folder
            )

            // Upload thumbnail if available (and if video)
            uploadProgress = 0.6
            var thumbnailUrl: String?
            
            if mediaType == .video,
               let thumbnail = thumbnailImage,
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
                thumbnailUrl = try await VibeService.shared.uploadMedia(
                    data: thumbnailData,
                    fileType: "jpg",
                    folder: "thumbnails"
                )
            } else if mediaType == .photo {
                thumbnailUrl = mediaUrl
            }

            // Create vibe with text overlay and song
            uploadProgress = 0.9
            try await appState.createVibe(
                type: mediaType,
                mediaUrl: mediaUrl,
                thumbnailUrl: thumbnailUrl,
                songData: song,
                textStatus: overlayText,
                isLocked: isLocked
            )

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

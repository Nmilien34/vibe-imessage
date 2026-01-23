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
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 24) {
            if let thumbnail = thumbnailImage {
                // Preview
                ZStack {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(16)
                        .frame(maxHeight: 300)

                    // Play icon overlay (only for video)
                    if mediaType == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Change media button
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                mediaData = nil
                                thumbnailImage = nil
                                selectedItem = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 5)
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
            } else {
                // Media picker options
                VStack(spacing: 16) {
                    // Camera option
                    Button {
                        showCamera = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Record Video")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    }

                    // Photo library option
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .any(of: [.videos, .images]),
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Choose from Library")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Error message
            if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            // Upload progress or share button
            if isUploading {
                VStack(spacing: 8) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(.linear)
                    Text("Uploading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if mediaData != nil {
                Button {
                    Task {
                        await shareMedia()
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Share Vibez")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .onChange(of: selectedItem) { _, newValue in
            Task {
                await loadMedia(from: newValue)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { data, thumbnail in
                mediaData = data
                thumbnailImage = thumbnail
                mediaType = .video
                showCamera = false
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

    private func shareMedia() async {
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
            // For photos, the mediaURL itself is the image, but we might want a smaller thumb?
            // For simplicity, for photos we use mediaUrl as thumbnail too or upload same data if needed.
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
                // For photos, thumbnail is just the photo itself or a resized version.
                // We'll just define the main image as the mediaUrl.
                thumbnailUrl = mediaUrl
            }

            // Create vibe
            uploadProgress = 0.9
            try await appState.createVibe(
                type: mediaType,
                mediaUrl: mediaUrl,
                thumbnailUrl: thumbnailUrl,
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

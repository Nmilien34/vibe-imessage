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
    @State private var videoData: Data?
    @State private var thumbnailImage: UIImage?
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

                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8))

                    // Change video button
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                videoData = nil
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
                // Video picker options
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
                        matching: .videos,
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
            } else if videoData != nil {
                Button {
                    Task {
                        await shareVideo()
                    }
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Share Vibe")
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
                await loadVideo(from: newValue)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { data, thumbnail in
                videoData = data
                thumbnailImage = thumbnail
                showCamera = false
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                videoData = data
                thumbnailImage = await generateThumbnail(from: data)
            }
        } catch {
            self.error = "Failed to load video"
        }
    }

    private func generateThumbnail(from data: Data) async -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        try? data.write(to: tempURL)

        let asset = AVAsset(url: tempURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            try? FileManager.default.removeItem(at: tempURL)
            return UIImage(cgImage: cgImage)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }

    private func shareVideo() async {
        guard let videoData = videoData else { return }

        isUploading = true
        error = nil

        do {
            // Upload video
            uploadProgress = 0.3
            let mediaUrl = try await VibeService.shared.uploadMedia(
                data: videoData,
                fileType: "mp4",
                folder: "vibes"
            )

            // Upload thumbnail if available
            uploadProgress = 0.6
            var thumbnailUrl: String?
            if let thumbnail = thumbnailImage,
               let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
                thumbnailUrl = try await VibeService.shared.uploadMedia(
                    data: thumbnailData,
                    fileType: "jpg",
                    folder: "thumbnails"
                )
            }

            // Create vibe
            uploadProgress = 0.9
            try await appState.createVibe(
                type: .video,
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

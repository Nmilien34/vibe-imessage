import SwiftUI
import AVFoundation
import PhotosUI

struct BetResolutionComposerView: View {
    @EnvironmentObject var appState: AppState

    let bet: Bet
    let outcome: BetOutcome
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var thumbnailImage: UIImage?
    @State private var mediaType: VibeType = .video
    @State private var isSubmitting = false
    @State private var submitProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var pendingOverlayText: String?

    var body: some View {
        VStack(spacing: 0) {
            if let data = mediaData {
                MediaEditorView(
                    mediaType: mediaType,
                    mediaData: data,
                    thumbnail: thumbnailImage,
                    isLocked: false,
                    onShare: { overlayText, _ in
                        await submitProofClaim(overlayText: overlayText)
                    },
                    onCancel: {
                        mediaData = nil
                        thumbnailImage = nil
                        selectedItem = nil
                    }
                )
            } else {
                CreatorCameraView(
                    initialLocked: false,
                    selectedItem: $selectedItem,
                    mediaData: $mediaData,
                    thumbnail: $thumbnailImage,
                    mediaType: $mediaType,
                    onClose: onCancel
                )
            }

            if isSubmitting {
                submitOverlay
            }

            if showError {
                Color.black.opacity(0.6).ignoresSafeArea()
                UploadErrorView(
                    error: errorMessage,
                    onRetry: {
                        showError = false
                        Task {
                            await submitProofClaim(overlayText: pendingOverlayText)
                        }
                    },
                    onCancel: {
                        showError = false
                        errorMessage = nil
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

    private var submitOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: submitProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .padding(.horizontal, 40)

                Text(submitProgress < 0.7 ? "Uploading proof..." : "Submitting resolution...")
                    .foregroundColor(.white)
                    .font(VibeTypography.titleSmall)
            }
        }
    }

    private func loadMedia(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
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
            errorMessage = "Failed to load media."
            showError = true
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

    private func submitProofClaim(overlayText: String?) async {
        guard let data = mediaData else { return }

        pendingOverlayText = overlayText
        isSubmitting = true
        submitProgress = 0.2
        showError = false
        errorMessage = nil

        do {
            let proofMediaType: ProofMediaType
            let isVideoUpload: Bool
            switch mediaType {
            case .video:
                proofMediaType = .video
                isVideoUpload = true
            case .photo:
                proofMediaType = .photo
                isVideoUpload = false
            default:
                throw NSError(
                    domain: "BetResolutionComposerView",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Only photo or video proof is supported."]
                )
            }

            let upload = try await APIService.shared.uploadMedia(
                mediaData: data,
                userId: appState.userId,
                chatId: bet.chatId,
                isLocked: false,
                isVideo: isVideoUpload
            )

            guard let mediaKey = upload.videoKey else {
                throw NSError(
                    domain: "BetResolutionComposerView",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Media upload succeeded but no media key was returned."]
                )
            }

            submitProgress = 0.7

            _ = try await appState.claimBetResolution(
                bet: bet,
                outcome: outcome,
                mediaType: proofMediaType,
                mediaUrl: upload.videoUrl,
                mediaKey: mediaKey,
                thumbnailUrl: nil,
                thumbnailKey: nil,
                caption: overlayText
            )

            submitProgress = 1.0
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSubmitting = false
    }
}

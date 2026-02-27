import SwiftUI
import AVFoundation
import PhotosUI

struct BetResolutionComposerView: View {
    @EnvironmentObject var appState: AppState

    let bet: Bet
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var thumbnailImage: UIImage?
    @State private var mediaType: VibeType = .video
    @State private var selectedOutcome: BetOutcome? = nil
    @State private var isSubmitting = false
    @State private var submitProgress: Double = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var pendingOverlayText: String?
    @State private var cameraText: String = ""

    // Creator of a callout/dare can mark it as ducked
    private var canDuck: Bool {
        (bet.betType == .callout || bet.betType == .dare) && bet.creatorId == appState.userId
    }

    var body: some View {
        ZStack {
            if let data = mediaData {
                if selectedOutcome == nil {
                    outcomePicker
                } else {
                    MediaEditorView(
                        mediaType: mediaType,
                        mediaData: data,
                        thumbnail: thumbnailImage,
                        isLocked: false,
                        initialOverlayText: cameraText,
                        onShare: { overlayText, _ in
                            await submitProofClaim(overlayText: overlayText)
                        },
                        onCancel: {
                            // Back to outcome picker, not all the way to camera
                            selectedOutcome = nil
                        }
                    )
                }
            } else {
                CreatorCameraView(
                    initialLocked: false,
                    selectedItem: $selectedItem,
                    mediaData: $mediaData,
                    thumbnail: $thumbnailImage,
                    mediaType: $mediaType,
                    onClose: onCancel,
                    onTextCommitted: { text in
                        cameraText = text
                    }
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

    // MARK: - Outcome Picker

    private var outcomePicker: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        VibeHaptic.light()
                        mediaData = nil
                        thumbnailImage = nil
                        selectedItem = nil
                        cameraText = ""
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(VibeTheme.textPrimary)
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    }

                    Spacer()

                    Text("Your Claim")
                        .font(VibeTypography.titleLarge)
                        .foregroundColor(VibeTheme.textPrimary)

                    Spacer()

                    Color.clear.frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
                .padding(.top, VibeSpacing.md)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: VibeSpacing.lg) {
                        // Thumbnail preview
                        if let thumb = thumbnailImage {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium))
                        } else {
                            RoundedRectangle(cornerRadius: VibeTheme.radiusMedium)
                                .fill(VibeTheme.surfaceOverlay)
                                .frame(maxWidth: .infinity, minHeight: 120)
                                .overlay(
                                    Image(systemName: mediaType == .video ? "video.fill" : "photo.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(VibeTheme.textTertiary)
                                )
                        }

                        // Prompt
                        VStack(spacing: VibeSpacing.xs) {
                            Text("Who won this bet?")
                                .font(VibeTypography.titleMedium)
                                .foregroundColor(VibeTheme.textPrimary)

                            Text("The other side will have a chance to confirm or dispute your claim before it's finalised.")
                                .font(VibeTypography.bodySmall)
                                .foregroundColor(VibeTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }

                        // Outcome buttons
                        VStack(spacing: VibeSpacing.sm) {
                            Button {
                                VibeHaptic.medium()
                                withAnimation(VibeAnimation.snappy) {
                                    selectedOutcome = .yes
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("YES Side Won")
                                        .fontWeight(.semibold)
                                }
                                .font(VibeTypography.titleSmall)
                                .frame(maxWidth: .infinity)
                                .padding(VibeSpacing.md)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .continuousCorner(VibeTheme.radiusMedium)
                            }
                            .buttonStyle(VibePressStyle())

                            Button {
                                VibeHaptic.medium()
                                withAnimation(VibeAnimation.snappy) {
                                    selectedOutcome = .no
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("NO Side Won")
                                        .fontWeight(.semibold)
                                }
                                .font(VibeTypography.titleSmall)
                                .frame(maxWidth: .infinity)
                                .padding(VibeSpacing.md)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .continuousCorner(VibeTheme.radiusMedium)
                            }
                            .buttonStyle(VibePressStyle())

                            if canDuck {
                                Button {
                                    VibeHaptic.medium()
                                    withAnimation(VibeAnimation.snappy) {
                                        selectedOutcome = .ducked
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                        Text("They Ducked")
                                            .fontWeight(.semibold)
                                    }
                                    .font(VibeTypography.titleSmall)
                                    .frame(maxWidth: .infinity)
                                    .padding(VibeSpacing.md)
                                    .background(VibeTheme.surfaceOverlay)
                                    .foregroundColor(VibeTheme.textSecondary)
                                    .continuousCorner(VibeTheme.radiusMedium)
                                }
                                .buttonStyle(VibePressStyle())
                            }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                    .padding(.top, VibeSpacing.lg)
                    .padding(.bottom, VibeSpacing.xxxl)
                }
            }
        }
    }

    // MARK: - Submit Overlay

    private var submitOverlay: some View {
        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView(value: submitProgress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.green)
                    .padding(.horizontal, 40)

                Text(submitProgress < 0.7 ? "Uploading receipts..." : "Finalizing result...")
                    .foregroundColor(.white)
                    .font(VibeTypography.titleSmall)
            }
        }
    }

    // MARK: - Media Loading

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

    // MARK: - Submission

    private func submitProofClaim(overlayText: String?) async {
        guard let data = mediaData, let outcome = selectedOutcome else { return }

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
                    userInfo: [NSLocalizedDescriptionKey: "Only photo or video receipts are supported."]
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

            submitProgress = 0.6

            // Upload thumbnail if available
            var thumbUrl: String? = nil
            var thumbKey: String? = nil
            if proofMediaType == .photo {
                // Photo is its own thumbnail
                thumbUrl = upload.videoUrl
                thumbKey = mediaKey
            } else if let thumbImage = thumbnailImage,
                      let jpegData = thumbImage.jpegData(compressionQuality: 0.7) {
                // Upload video thumbnail separately
                let thumbResult = try? await VibeService.shared.uploadMediaWithKey(
                    data: jpegData,
                    fileType: "jpg",
                    folder: "thumbnails"
                )
                thumbUrl = thumbResult?.url
                thumbKey = thumbResult?.key
            }

            submitProgress = 0.7

            _ = try await appState.claimBetResolution(
                bet: bet,
                outcome: outcome,
                mediaType: proofMediaType,
                mediaUrl: upload.videoUrl,
                mediaKey: mediaKey,
                thumbnailUrl: thumbUrl,
                thumbnailKey: thumbKey,
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

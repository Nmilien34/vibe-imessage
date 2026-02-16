import SwiftUI
import PhotosUI

struct LeakComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var mediaData: Data?
    @State private var thumbnailImage: UIImage?
    @State private var isUploading = false
    @State private var showNoContextTag = true
    @State private var showUploadError = false
    @State private var uploadError: String?

    var body: some View {
        VStack(spacing: VibeSpacing.xl) {
            if let thumbnail = thumbnailImage {
                VStack(spacing: VibeSpacing.lg) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .continuousCorner(VibeTheme.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                    .stroke(VibeTheme.divider, lineWidth: 1)
                            )

                        if showNoContextTag {
                            Text("NO CONTEXT")
                                .font(VibeTypography.overline)
                                .padding(.horizontal, VibeSpacing.xs)
                                .padding(.vertical, VibeSpacing.xxs)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .continuousCorner(4)
                                .padding(VibeSpacing.sm)
                        }

                        Button {
                            VibeHaptic.light()
                            thumbnailImage = nil
                            mediaData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(VibeSpacing.xs)
                    }

                    Toggle("Add 'No Context' Tag", isOn: $showNoContextTag)
                        .font(VibeTypography.bodyMedium)
                        .padding(.horizontal, VibeSpacing.screenHorizontal)

                    Button {
                        VibeHaptic.success()
                        Task { await shareLeak() }
                    } label: {
                        HStack(spacing: VibeSpacing.xs) {
                            if isUploading {
                                ProgressView().tint(.white)
                                Text("Uploading...")
                                    .font(VibeTypography.titleSmall)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Leak It")
                                    .font(VibeTypography.titleSmall)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: VibeSpacing.minTouchTarget)
                        .background(isUploading ? Color.red.opacity(0.6) : Color.red)
                        .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                    .disabled(isUploading)
                }
            } else {
                VStack(spacing: VibeSpacing.xxl) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red.opacity(0.5))

                    Text("Select a receipt to leak...")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(VibeTheme.textPrimary)

                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: VibeSpacing.sm) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 28))
                            Text("Open Gallery")
                                .font(VibeTypography.titleSmall)
                        }
                        .foregroundColor(VibeTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VibeSpacing.xxxl)
                        .background(.ultraThinMaterial)
                        .continuousCorner(VibeTheme.radiusLarge)
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)

                    Text("Leaks are optimized for screenshots.")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(VibeTheme.textTertiary)
                }
                .padding(.top, VibeSpacing.xxxl)
            }

            Spacer()

            if showUploadError {
                Color.black.opacity(0.6).ignoresSafeArea()
                UploadErrorView(
                    error: uploadError,
                    onRetry: {
                        showUploadError = false
                        Task { await shareLeak() }
                    },
                    onCancel: {
                        showUploadError = false
                        uploadError = nil
                    }
                )
                .padding()
            }
        }
        .padding(.top, VibeSpacing.md)
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let resized = image.preparingForUpload(maxDimension: 1920)
                    self.thumbnailImage = resized
                    self.mediaData = resized.jpegData(compressionQuality: 0.8)
                }
            }
        }
    }

    private func shareLeak() async {
        guard let data = mediaData else { return }
        isUploading = true
        showUploadError = false
        uploadError = nil

        do {
            let result = try await VibeService.shared.uploadMediaWithKey(data: data, fileType: "jpg", folder: "leaks")
            let vibe = try await appState.createVibe(
                type: .leak,
                mediaUrl: result.url,
                mediaKey: result.key,
                thumbnailUrl: result.url,
                thumbnailKey: result.key,
                textStatus: showNoContextTag ? "NO CONTEXT" : nil,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, thumbnail: thumbnailImage, vibeType: .leak)
            appState.dismissComposer()
        } catch {
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploading = false
    }
}

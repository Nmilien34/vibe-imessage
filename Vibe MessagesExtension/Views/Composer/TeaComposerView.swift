import SwiftUI
import PhotosUI

struct TeaComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var textStatus = ""
    @State private var selectedStyle: TeaStyle = .neon
    @FocusState private var isFocused: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var imageData: Data?
    @State private var isUploading = false
    @State private var showUploadError = false
    @State private var uploadError: String?

    enum TeaStyle: String, CaseIterable, Identifiable {
        case neon = "Neon"
        case noir = "Noir"
        case fire = "Fire"
        case photo = "Photo"

        var id: String { self.rawValue }

        var colors: [Color] {
            switch self {
            case .neon: return [.purple, .blue, .cyan]
            case .noir: return [.black, .gray, .gray.opacity(0.8)]
            case .fire: return [.orange, .red, .yellow]
            case .photo: return [.black.opacity(0.5)]
            }
        }
    }

    var body: some View {
        VStack(spacing: VibeSpacing.xl) {
            // Preview Card
            ZStack {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 350, height: 300)
                        .overlay(Color.black.opacity(0.3))
                        .continuousCorner(VibeTheme.radiusLarge)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: selectedStyle.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .continuousCorner(VibeTheme.radiusLarge)
                }

                VStack {
                    TextField("Spill the tea...", text: $textStatus, axis: .vertical)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .focused($isFocused)
                        .background(Color.white.opacity(0.1))
                        .continuousCorner(VibeTheme.radiusMedium)
                        .padding()
                }
            }
            .frame(height: 300)
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .vibeShadow(.lg)

            // Style Selector
            VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                Text("STYLE")
                    .vibeSectionHeader()
                    .padding(.horizontal, VibeSpacing.screenHorizontal)

                HStack(spacing: VibeSpacing.sm) {
                    ForEach(TeaStyle.allCases) { style in
                        if style == .photo {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Photo", systemImage: "photo.fill")
                                    .font(VibeTypography.captionLarge)
                                    .padding(.horizontal, VibeSpacing.md)
                                    .padding(.vertical, VibeSpacing.xs)
                                    .background(backgroundImage != nil ? VibeTheme.textPrimary : Color.clear)
                                    .foregroundColor(backgroundImage != nil ? VibeTheme.background : VibeTheme.textPrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                            .stroke(VibeTheme.textPrimary, lineWidth: 1)
                                    )
                                    .continuousCorner(VibeTheme.radiusMedium)
                            }
                        } else {
                            Button {
                                VibeHaptic.light()
                                withAnimation(VibeAnimation.snappy) {
                                    selectedStyle = style
                                    backgroundImage = nil
                                    imageData = nil
                                }
                            } label: {
                                Text(style.rawValue)
                                    .font(VibeTypography.captionLarge)
                                    .padding(.horizontal, VibeSpacing.md)
                                    .padding(.vertical, VibeSpacing.xs)
                                    .background(selectedStyle == style && backgroundImage == nil ? VibeTheme.textPrimary : Color.clear)
                                    .foregroundColor(selectedStyle == style && backgroundImage == nil ? VibeTheme.background : VibeTheme.textPrimary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                            .stroke(VibeTheme.textPrimary, lineWidth: 1)
                                    )
                                    .continuousCorner(VibeTheme.radiusMedium)
                            }
                        }
                    }
                }
                .padding(.horizontal, VibeSpacing.screenHorizontal)
            }

            Spacer()

            // Share Button
            Button {
                VibeHaptic.success()
                Task { await shareTea() }
            } label: {
                HStack {
                    if isUploading {
                        ProgressView().tint(.white)
                        Text("Spilling...")
                            .font(VibeTypography.titleSmall)
                    } else {
                        Text("Spill Tea")
                            .font(VibeTypography.titleSmall)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget)
                .background(VibeTheme.teaGradient)
                .opacity(isUploading ? 0.6 : 1.0)
                .continuousCorner(VibeTheme.radiusMedium)
            }
            .buttonStyle(VibePressStyle())
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .disabled(textStatus.isEmpty || isUploading)
            .opacity(textStatus.isEmpty ? 0.5 : 1.0)

            if showUploadError {
                Color.black.opacity(0.6).ignoresSafeArea()
                UploadErrorView(
                    error: uploadError,
                    onRetry: {
                        showUploadError = false
                        Task { await shareTea() }
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
        .onAppear { isFocused = true }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    self.imageData = data
                    self.backgroundImage = UIImage(data: data)
                    self.selectedStyle = .photo
                }
            }
        }
    }

    private func shareTea() async {
        isUploading = true
        showUploadError = false
        uploadError = nil
        var mediaUrl: String?
        var mediaKey: String?

        do {
            if let data = imageData {
                let result = try await VibeService.shared.uploadMediaWithKey(data: data, fileType: "jpg", folder: "tea")
                mediaUrl = result.url
                mediaKey = result.key
            }

            let vibe = try await appState.createVibe(
                type: .tea,
                mediaUrl: mediaUrl,
                mediaKey: mediaKey,
                thumbnailUrl: mediaUrl,
                thumbnailKey: mediaKey,
                textStatus: textStatus,
                styleName: selectedStyle.rawValue,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .tea, contextText: textStatus)
            appState.dismissComposer()
        } catch {
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploading = false
    }
}

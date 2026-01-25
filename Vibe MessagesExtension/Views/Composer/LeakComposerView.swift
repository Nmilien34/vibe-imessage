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
        VStack(spacing: 24) {
            if let thumbnail = thumbnailImage {
                // Selected Preview
                VStack(spacing: 20) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        
                        if showNoContextTag {
                            Text("NO CONTEXT")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                                .padding(12)
                        }
                        
                        Button {
                            thumbnailImage = nil
                            mediaData = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8)
                    }
                    
                    Toggle("Add 'No Context' Tag", isOn: $showNoContextTag)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await shareLeak()
                        }
                    } label: {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                Text("Uploading...")
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("Leak It 🫣")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUploading ? Color.red.opacity(0.6) : Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(isUploading)
                }
            } else {
                // Rapid Select / Empty State
                VStack(spacing: 32) {
                    Image(systemName: "shutter.releaser")
                        .font(.system(size: 60))
                        .foregroundColor(.red.opacity(0.5))
                    
                    Text("Select a receipt to leak...")
                        .font(.headline)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title)
                            Text("Open Gallery")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    
                    Text("Leaks are optimized for screenshots.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            }
            
            Spacer()

            // Upload Error Overlay
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
        .padding(.top, 16)
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    self.mediaData = data
                    self.thumbnailImage = UIImage(data: data)
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
            try await appState.createVibe(
                type: .leak,
                mediaUrl: result.url,
                mediaKey: result.key,
                thumbnailUrl: result.url,
                thumbnailKey: result.key,
                textStatus: showNoContextTag ? "NO CONTEXT" : nil,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploading = false
    }
}

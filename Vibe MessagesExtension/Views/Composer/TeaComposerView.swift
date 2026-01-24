import PhotosUI

struct TeaComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var textStatus = ""
    @State private var selectedStyle: TeaStyle = .neon
    @FocusState private var isFocused: Bool
    
    // Image Background State
    @State private var selectedItem: PhotosPickerItem?
    @State private var backgroundImage: UIImage?
    @State private var imageData: Data?
    @State private var isUploading = false
    
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
            case .photo: return [.black.opacity(0.5)] // Fallback
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Preview Card
            ZStack {
                if let image = backgroundImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 350, height: 300)
                        .overlay(Color.black.opacity(0.3)) // Overlay for text readability
                        .cornerRadius(24)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: selectedStyle.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .cornerRadius(24)
                }
                
                VStack {
                    TextField("Spill the tea...", text: $textStatus, axis: .vertical)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .focused($isFocused)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding()
                }
            }
            .frame(height: 300)
            .padding(.horizontal)
            .shadow(radius: 10)
            
            // Style Selector & Photo Picker
            VStack(alignment: .leading, spacing: 12) {
                Text("STYLE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 12) {
                    ForEach(TeaStyle.allCases) { style in
                        if style == .photo {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("Photo", systemImage: "photo.fill")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(backgroundImage != nil ? Color.primary : Color.clear)
                                    .foregroundColor(backgroundImage != nil ? Color(.systemBackground) : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                            }
                        } else {
                            Button {
                                withAnimation {
                                    selectedStyle = style
                                    backgroundImage = nil
                                    imageData = nil
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            } label: {
                                Text(style.rawValue)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedStyle == style && backgroundImage == nil ? Color.primary : Color.clear)
                                    .foregroundColor(selectedStyle == style && backgroundImage == nil ? Color(.systemBackground) : .primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.primary, lineWidth: 1)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Share Button
            Button {
                Task {
                    await shareTea()
                }
            } label: {
                if isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Spill Tea ☕️")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brown)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .disabled(textStatus.isEmpty || isUploading)
            .opacity(textStatus.isEmpty || isUploading ? 0.5 : 1.0)
        }
        .padding(.top, 16)
        .onAppear {
            isFocused = true
        }
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
        var mediaUrl: String?
        
        do {
            if let data = imageData {
                mediaUrl = try await VibeService.shared.uploadMedia(data: data, fileType: "jpg", folder: "tea")
            }
            
            try await appState.createVibe(
                type: .tea,
                mediaUrl: mediaUrl,
                thumbnailUrl: mediaUrl,
                textStatus: textStatus,
                styleName: selectedStyle.rawValue,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            print("Error sharing tea: \(error)")
        }
        isUploading = false
    }
}

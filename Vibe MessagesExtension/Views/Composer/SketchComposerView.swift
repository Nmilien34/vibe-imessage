import SwiftUI

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

struct SketchComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var lines: [Line] = []
    @State private var currentLine = Line(points: [], color: .cyan, lineWidth: 5)
    @State private var selectedColor: Color = .cyan
    @State private var isUploading = false
    @State private var showUploadError = false
    @State private var uploadError: String?
    
    let colors: [Color] = [.cyan, .pink, .green, .yellow, .white]
    
    var body: some View {
        VStack(spacing: 24) {
            // Canvas Area
            canvasView
                .frame(height: 400)
                .padding(.horizontal)
                .overlay(alignment: .topTrailing) {
                    Button {
                        lines = []
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(24)
                    }
                }
            
            // Tool Palette
            HStack(spacing: 20) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        currentLine.color = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .shadow(color: color.opacity(0.5), radius: 5)
                    }
                }
            }
            
            Spacer()
            
            // Share Button
            Button {
                Task {
                    await shareSketch()
                }
            } label: {
                if isUploading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedColor)
                        .cornerRadius(12)
                } else {
                    Text("Send Doodle 🎨")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedColor)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .disabled(lines.isEmpty || isUploading)
            .opacity(lines.isEmpty || isUploading ? 0.5 : 1.0)

            // Upload Error Overlay
            if showUploadError {
                Color.black.opacity(0.6).ignoresSafeArea()
                UploadErrorView(
                    error: uploadError,
                    onRetry: {
                        showUploadError = false
                        Task { await shareSketch() }
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
    }

    // Extracted canvas view for rendering
    private var canvasView: some View {
        ZStack {
            Color.black
                .cornerRadius(24)
            
            Canvas { context, size in
                for line in lines {
                    var path = Path()
                    path.addLines(line.points)
                    context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
                }
                
                var path = Path()
                path.addLines(currentLine.points)
                context.stroke(path, with: .color(currentLine.color), lineWidth: currentLine.lineWidth)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPoint = value.location
                        currentLine.points.append(newPoint)
                    }
                    .onEnded { _ in
                        lines.append(currentLine)
                        currentLine = Line(points: [], color: selectedColor, lineWidth: 5)
                    }
            )
        }
    }
    
    private func shareSketch() async {
        isUploading = true
        showUploadError = false
        uploadError = nil

        do {
            // 1. Render canvas to UIImage
            let renderer = ImageRenderer(content: canvasView.frame(width: 400, height: 400))
            renderer.scale = 3.0 // High quality
            
            guard let image = renderer.uiImage,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "SketchError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to render drawing"])
            }

            // 2. Get Presigned URL
            let presignedResponse: APIClient.PresignedUrlResponse = try await APIClient.shared.post("/api/upload/presigned-url", body: [
                "fileType": "jpg",
                "folder": "sketches"
            ])

            // 3. Upload to S3
            guard let uploadUrl = URL(string: presignedResponse.uploadUrl) else {
                throw NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
            }

            var request = URLRequest(url: uploadUrl)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            
            let (_, response) = try await URLSession.shared.upload(for: request, from: imageData)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "S3Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to upload sketch to storage"])
            }

            // 4. Create Vibe with the public URL
            let vibe = try await appState.createVibe(
                type: .sketch,
                mediaUrl: presignedResponse.publicUrl,
                isLocked: isLocked
            )
            
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .sketch)
            appState.dismissComposer()
        } catch {
            print("Sketch sharing failed: \(error)")
            uploadError = error.localizedDescription
            showUploadError = true
        }
        isUploading = false
    }
}

//
//  CameraView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    @StateObject private var model = CameraViewModel()
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    // Callback for when a video is recorded
    var onFinish: ((Data?, UIImage?) -> Void)?
    
    // Internal state to track if we've handled the recording completion
    @State private var hasFinished = false
    
    init(onFinish: ((Data?, UIImage?) -> Void)? = nil) {
        self.onFinish = onFinish
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if model.session != nil || model.isSimulator {
                // Preview Layer
                if let session = model.session {
                    CameraPreviewView(session: session)
                        .ignoresSafeArea()
                } else {
                    // Simulator Placeholder
                    ZStack {
                        Color.gray.opacity(0.3).ignoresSafeArea()
                        Text("Simulator Camera Mode\nTap Record to Test")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                    }
                }
                
                // Top Bar
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                        }
                        Spacer()
                    }
                    Spacer()
                }
                
                // Controls Overlay
                VStack {
                    Spacer()
                    
                    HStack(spacing: 40) {
                        Button {
                            model.flipCamera()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        
                        // Recording Button
                        Button {
                            if model.isRecording {
                                model.stopRecording()
                            } else {
                                model.startRecording()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 80, height: 80)
                                
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: model.isRecording ? 30 : 70, height: model.isRecording ? 30 : 70)
                                    .cornerRadius(model.isRecording ? 4 : 35)
                                    .animation(.easeInOut, value: model.isRecording)
                            }
                        }
                        
                        // Timer / Duration
                        if model.isRecording {
                            Text(String(format: "%.1f", model.recordingTime))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(width: 50)
                        } else {
                            // Placeholder for balance
                            Spacer()
                                .frame(width: 50)
                        }
                    }
                    .padding(.bottom, 30)
                }
            } else {
                VStack {
                    if model.isUnauthorized {
                        Text("Camera access denied")
                            .foregroundColor(.white)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                    } else {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            }
        }
        .onAppear {
            model.checkPermissions()
        }
        .onDisappear {
            model.stopSession()
        }
        .onChange(of: model.recordedVideo) { _, newVideo in
            guard let video = newVideo, !hasFinished else { return }
            hasFinished = true
            
            // Generate thumbnail and data
            Task {
                if let videoData = try? Data(contentsOf: video.url) {
                    let thumbnail = await generateThumbnail(for: video.url)
                    onFinish?(videoData, thumbnail)
                    dismiss()
                }
            }
        }
    }
    
    private func generateThumbnail(for url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

#Preview {
    CameraView()
}

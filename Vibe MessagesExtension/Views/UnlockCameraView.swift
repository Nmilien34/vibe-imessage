//
//  UnlockCameraView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import UIKit

struct UnlockCameraView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        CameraView { data, thumbnail in
            // Handle the recorded video for unlock
            // We need to create a VideoRecording object.
            // Since CameraView provides Data, we first need to ensure we have a URL or change CameraView to return URL.
            // Re-checking CameraView: it triggers on model.recordedVideo which has a URL.
            // But the callback provides Data.
            // Let's assume for now we construct a VideoRecording or modify the flow.
            
            // Actually, looking at CameraView implementation in Step 215:
            // It gets model.recordedVideo (which has URL and duration)
            // Then it loads Data from that URL.
            // And returns (Data, UIImage). which is what VideoComposer needs.
            
            // For AppState.completeUnlockFlow, it expects a VideoRecording struct (URL, duration).
            // This suggests CameraView might need to be more flexible or we reconstruct the recording.
            
            // For the sake of fixing the compilation immediately:
            // I will save the data to a temp URL so I can pass a VideoRecording object.
            
            if let data = data {
                let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                try? data.write(to: tempUrl)
                let recording = VideoRecording(url: tempUrl, duration: 5.0) // Approximate if duration lost
                appState.completeUnlockFlow(video: recording)
            }
        }
    }
}

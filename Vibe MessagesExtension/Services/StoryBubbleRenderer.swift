//
//  StoryBubbleRenderer.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import UIKit
import SwiftUI

class StoryBubbleRenderer {
    static let shared = StoryBubbleRenderer()
    
    private init() {}
    
    /// Renders a story bubble image with the given parameters
    @MainActor
    func renderStoryBubble(thumbnail: UIImage?, expiresIn: Int, isLocked: Bool) -> UIImage {
        let view = StoryBubbleView(
            thumbnail: thumbnail,
            expiresIn: expiresIn,
            isLocked: isLocked
        )
        
        let renderer = ImageRenderer(content: view)
        renderer.scale = UITraitCollection.current.displayScale
        
        return renderer.uiImage ?? UIImage(systemName: "exclamationmark.triangle")!
    }
}

// SwiftUI view that represents the bubble layout
struct StoryBubbleView: View {
    let thumbnail: UIImage?
    let expiresIn: Int
    let isLocked: Bool
    
    var body: some View {
        ZStack {
            // Background / Thumbnail
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 300, height: 200)
                    .overlay(Color.black.opacity(isLocked ? 0.3 : 0.1))
            } else {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 300, height: 200)
            }
            
            // Gradient Overlay
            LinearGradient(
                colors: [.black.opacity(0.6), .transparent, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Lock UI
            if isLocked {
                VStack {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .shadow(radius: 10)
                        
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                    
                    Text("Tap to Unveil")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 8)
                        .shadow(radius: 4)
                }
            } else {
                // Play Icon
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.8))
                    .shadow(radius: 4)
            }
            
            // Footer Info
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Expires in \(expiresIn)h")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Vibez")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.pink)
                        .cornerRadius(8)
                }
                .foregroundColor(.white)
                .padding()
            }
        }
        .frame(width: 300, height: 200)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [.pink, .purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
    }
}

extension Color {
    static let transparent = Color.black.opacity(0)
}

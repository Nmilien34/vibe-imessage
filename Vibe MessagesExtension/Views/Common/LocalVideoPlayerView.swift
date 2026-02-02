//
//  LocalVideoPlayerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/30/26.
//

import SwiftUI
import AVKit

struct LocalVideoPlayerView: View {
    let videoName: String
    let videoType: String
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                        isPlaying = true
                        
                        // Loop the video
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                Color.black
                    .overlay(
                        Text("Video not found")
                            .foregroundColor(.white)
                    )
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        guard let path = Bundle.main.path(forResource: videoName, ofType: videoType) else {
            print("[\(videoName).\(videoType)] not found in bundle")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        self.player = AVPlayer(url: url)
    }
}

#Preview {
    LocalVideoPlayerView(videoName: "PartyVibej", videoType: "mp4")
}

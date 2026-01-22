//
//  RootView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.currentDestination {
            case .feed:
                FeedView()
            case .viewer(let startIndex):
                VibeViewerView(startIndex: startIndex)
            case .composer:
                ComposerView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.currentDestination)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}

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
        ZStack {
            // Main content
            Group {
                if !appState.isOnboardingCompleted {
                    OnboardingSlideshowView()
                } else if !appState.isAuthenticated {
                    LoginView()
                } else if !appState.isBirthdayCollected {
                    BirthdayCollectionView()
                } else if !appState.hasRequiredPermissions {
                    PermissionRequestView()
                } else {
                    switch appState.currentDestination {
                    case .feed:
                        FeedView()
                    case .viewer(let startIndex):
                        VibeViewerView(startIndex: startIndex)
                    case .composer:
                        ComposerView()
                    case .unlockComposer:
                        UnlockCameraView()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: appState.currentDestination)

            // Unlock prompt overlay
            if appState.showUnlockPrompt {
                UnlockPromptView(
                    senderName: appState.lockedMessageParams?.senderName ?? "Someone",
                    onOpenCamera: {
                        appState.startUnlockRecording()
                    },
                    onDismiss: {
                        appState.dismissUnlockPrompt()
                    }
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: appState.showUnlockPrompt)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}

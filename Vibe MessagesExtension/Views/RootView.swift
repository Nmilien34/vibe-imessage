//
//  RootView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasRendered = false
    @State private var showResetOption = false

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

            // Emergency reset option (appears after long press anywhere)
            if showResetOption {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showResetOption = false
                    }

                VStack(spacing: 20) {
                    Text("Having trouble?")
                        .font(.headline)
                        .foregroundColor(.white)

                    Button {
                        resetAppState()
                        showResetOption = false
                    } label: {
                        Text("Reset App")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(12)
                    }

                    Button {
                        showResetOption = false
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear {
            hasRendered = true
            print("RootView Debug: Rendered. Onboarding=\(appState.isOnboardingCompleted), Auth=\(appState.isAuthenticated), Birthday=\(appState.isBirthdayCollected), Perms=\(appState.hasRequiredPermissions)")
        }
        // Use simultaneousGesture so it doesn't block button taps
        // REMOVED: LongPressGesture was causing "System gesture gate timed out" issues
        // .simultaneousGesture(
        //     LongPressGesture(minimumDuration: 3.0)
        //         .onEnded { _ in
        //             showResetOption = true
        //         }
        // )
    }

    private func resetAppState() {
        // Clear all UserDefaults related to the app
        let keys = [
            "vibeOnboardingCompleted",
            "vibeUserId",
            "vibeAuthToken",
            "vibeUserFirstName",
            "vibeBirthdayCollected",
            "vibeBirthdayMonth",
            "vibeBirthdayDay",
            "vibePermissionsGranted"
        ]

        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Reset app state to initial values
        appState.isOnboardingCompleted = false
        appState.isAuthenticated = false
        appState.isBirthdayCollected = false
        appState.hasRequiredPermissions = false
        appState.userId = "anonymous"
        appState.userFirstName = nil

        print("RootView Debug: App state has been reset")
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
}

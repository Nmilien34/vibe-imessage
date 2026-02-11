//
//  UnlockPromptView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct UnlockPromptView: View {
    /// The name of the person whose story is locked
    let senderName: String

    /// Called when user taps "Open Camera"
    let onOpenCamera: () -> Void

    /// Called when user dismisses the prompt
    let onDismiss: () -> Void

    @State private var animatePulse = false
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    VibeHaptic.light()
                    onDismiss()
                }

            // Modal content
            VStack(spacing: VibeSpacing.xxl) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: {
                        VibeHaptic.light()
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, VibeSpacing.xxxs)

                Spacer()

                // App icon
                appIcon

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(VibeTheme.brandGradient)
                    .symbolEffect(.pulse)
                    .padding(.top, VibeSpacing.sm)

                // Prompt text
                VStack(spacing: VibeSpacing.sm) {
                    Text("Post your story to unlock")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(.white)

                    Text("\(senderName)'s Vibe!")
                        .font(VibeTypography.titleLarge)
                        .foregroundStyle(VibeTheme.brandGradient)
                }
                .multilineTextAlignment(.center)

                Spacer()

                // Record button (big white circle)
                recordButton

                // "Open Camera" text button
                Button(action: {
                    VibeHaptic.medium()
                    onOpenCamera()
                }) {
                    Text("Open Camera")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xxxl)

                Spacer()
                    .frame(height: VibeSpacing.lg)
            }
            .padding(VibeSpacing.xxl)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .vibeShadow(.xl)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(VibeAnimation.bouncy) {
                isVisible = true
            }
        }
    }

    // MARK: - App Icon
    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VibeTheme.brandGradient)
                .frame(width: 80, height: 80)

            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white)
                .symbolEffect(.bounce)
        }
    }

    // MARK: - Record Button
    private var recordButton: some View {
        Button(action: {
            VibeHaptic.medium()
            onOpenCamera()
        }) {
            ZStack {
                // Pulsing ring animation
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(animatePulse ? 1.2 : 1.0)
                    .opacity(animatePulse ? 0 : 1)

                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 88, height: 88)

                // Inner white circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)

                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(VibeAnimation.smooth.speed(0.5).repeatForever(autoreverses: false)) {
                animatePulse = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    UnlockPromptView(
        senderName: "Alex",
        onOpenCamera: { print("Open camera") },
        onDismiss: { print("Dismissed") }
    )
}

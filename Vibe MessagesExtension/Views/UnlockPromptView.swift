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

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Modal content
            VStack(spacing: 24) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 4)

                Spacer()

                // App icon
                appIcon

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 8)

                // Prompt text
                VStack(spacing: 8) {
                    Text("Post your story to unlock")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text("\(senderName)'s Vibe!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .multilineTextAlignment(.center)

                Spacer()

                // Record button (big white circle)
                recordButton

                // "Open Camera" text button
                Button(action: onOpenCamera) {
                    Text("Open Camera")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 48)
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }

                Spacer()
                    .frame(height: 20)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 0.12))
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
        }
    }

    // MARK: - App Icon
    private var appIcon: some View {
        ZStack {
            // Gradient background
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.69, green: 0.33, blue: 0.94),
                            Color(red: 0.40, green: 0.45, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // App icon symbol
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Record Button
    private var recordButton: some View {
        Button(action: onOpenCamera) {
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
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
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

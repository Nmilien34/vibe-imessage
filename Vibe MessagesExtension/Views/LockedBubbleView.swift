//
//  LockedBubbleView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct LockedBubbleView: View {
    let senderName: String
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            // Blurred gradient background
            VibeTheme.brandGradient
                .blur(radius: 10)
                .overlay(
                    Color.black.opacity(0.3)
                )

            VStack(spacing: VibeSpacing.lg) {
                // Profile Picture (Placeholder)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
                    .vibeShadow(.sm)

                // Lock Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .shadow(color: VibeTheme.accent, radius: 10)
                    .symbolEffect(.pulse)

                VStack(spacing: VibeSpacing.sm) {
                    Text("Tap to Unveil")
                        .font(VibeTypography.titleSmall)
                        .foregroundColor(.white)

                    Text("Unlock \(senderName)'s update by posting your own.")
                        .font(VibeTypography.captionLarge)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal)
                }

                Spacer()

                // Bottom hint
                Button(action: {
                    VibeHaptic.medium()
                    onUnlock()
                }) {
                    Text("Tap to participate")
                        .font(VibeTypography.captionSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, VibeSpacing.lg)
                        .padding(.vertical, VibeSpacing.sm)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .buttonStyle(VibePressStyle())
                .padding(.bottom, VibeSpacing.md)
            }
            .padding(.top, VibeSpacing.xxl)
        }
        .frame(width: 250, height: 350)
        .continuousCorner(VibeTheme.radiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    LockedBubbleView(senderName: "Nick") {
        print("Unlock tapped")
    }
}

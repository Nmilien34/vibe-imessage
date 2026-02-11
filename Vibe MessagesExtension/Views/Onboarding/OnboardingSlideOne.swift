//
//  OnboardingSlideOne.swift
//  Vibe MessagesExtension
//
//  Created on 1/30/26.
//

import SwiftUI

struct OnboardingSlideOne: View {
    var onContinue: () -> Void
    @State private var isVisible = false

    var body: some View {
        ZStack {
            // LAYER 1: Background Image
            Image("OnboardingSkater")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)

            // LAYER 2: Content
            VStack(spacing: VibeSpacing.xxl) {
                Spacer()

                Text("Capture moments, share memories, and vibe with friends right inside iMessage.")
                    .font(VibeTypography.titleLarge)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VibeSpacing.xxxl)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 20)

                // Action Button
                Button(action: onContinue) {
                    Text("Next")
                        .font(VibeTypography.titleMedium)
                        .foregroundColor(.black)
                        .padding(.horizontal, VibeSpacing.xxxl + VibeSpacing.lg)
                        .padding(.vertical, VibeSpacing.md)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .vibeShadow(.lg)
                }
                .buttonStyle(VibePressStyle())
                .padding(.bottom, VibeSpacing.xxxl)
                .opacity(isVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.smooth.delay(0.3)) {
                isVisible = true
            }
        }
    }
}

#Preview {
    OnboardingSlideOne(onContinue: {})
}

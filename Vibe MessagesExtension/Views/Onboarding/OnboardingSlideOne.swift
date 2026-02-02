//
//  OnboardingSlideOne.swift
//  Vibe MessagesExtension
//
//  Created on 1/30/26.
//

import SwiftUI

struct OnboardingSlideOne: View {
    var onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // LAYER 1: The Background (Static Image)
            Image("OnboardingSkater")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
            
            // LAYER 2: The Content (Bottom Aligned)
            VStack(spacing: 32) {
                Spacer()
                
                // Subtitle
                Text("Capture moments, share memories, and vibe with friends right inside iMessage.")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2) // Added shadow for readability against busy background
                
                // Action Button
                Button(action: {
                    onContinue()
                }) {
                    Text("Next")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 60)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding(.bottom, 40) // Space from home indicator
            }
        }
    }
}

#Preview {
    OnboardingSlideOne(onContinue: {})
}

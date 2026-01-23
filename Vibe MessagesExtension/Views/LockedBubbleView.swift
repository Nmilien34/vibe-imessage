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
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0, blue: 0.6), // Purple
                    Color(red: 0, green: 0.2, blue: 0.8), // Blue
                    Color(red: 0.8, green: 0.3, blue: 0)  // Orange hints
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 10)
            .overlay(
                Color.black.opacity(0.3)
            )

            VStack(spacing: 16) {
                // Profile Picture (Placeholder)
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
                    .shadow(radius: 4)

                // Lock Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
                    .shadow(color: .purple, radius: 10)

                VStack(spacing: 8) {
                    Text("Tap to Unveil 🔒")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Unlock \(senderName)'s update by posting your own.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal)
                }
                
                Spacer()

                // Bottom hint
                Button(action: onUnlock) {
                    Text("Tap to participate")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.bottom, 12)
            }
            .padding(.top, 24)
        }
        .frame(width: 250, height: 350)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    LockedBubbleView(senderName: "Nick") {
        print("Unlock tapped")
    }
}

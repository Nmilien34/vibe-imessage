//
//  LoadingViews.swift
//  Vibe MessagesExtension
//
//  Centralized loading components.
//

import SwiftUI

// MARK: - Branded Loading Spinner

struct VibeLoadingSpinner: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(VibeTheme.brandGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 32, height: 32)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Full Screen Loading Overlay

struct VibeLoadingOverlay: View {
    let message: String?

    init(_ message: String? = nil) {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: VibeSpacing.md) {
                VibeLoadingSpinner()

                if let message {
                    Text(message)
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(.white)
                }
            }
            .padding(VibeSpacing.xxl)
            .background(.ultraThinMaterial)
            .continuousCorner(VibeTheme.radiusMedium)
        }
    }
}

// MARK: - Skeleton Placeholder

struct VibeSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16

    var body: some View {
        RoundedRectangle(cornerRadius: height / 3, style: .continuous)
            .fill(VibeTheme.surfaceOverlay)
            .frame(width: width, height: height)
            .vibeShimmer()
    }
}

// MARK: - Card Skeleton

struct VibeCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            VibeSkeleton(width: 120, height: 14)
            VibeSkeleton(height: 12)
            VibeSkeleton(width: 180, height: 12)
        }
        .padding(VibeSpacing.md)
        .vibeCard(radius: VibeTheme.radiusMedium)
    }
}

// MARK: - Previews

#Preview("Spinner") {
    VStack(spacing: 40) {
        VibeLoadingSpinner()
        VibeLoadingOverlay("Loading vibes...")
    }
}

#Preview("Skeletons") {
    VStack(spacing: 16) {
        VibeSkeleton(width: 200, height: 20)
        VibeSkeleton(height: 14)
        VibeCardSkeleton()
    }
    .padding()
}

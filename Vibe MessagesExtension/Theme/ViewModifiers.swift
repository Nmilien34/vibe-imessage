//
//  ViewModifiers.swift
//  Vibe MessagesExtension
//
//  Reusable view modifiers for consistent styling.
//

import SwiftUI

// MARK: - Continuous Corner Clip

extension View {
    func continuousCorner(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// MARK: - Card Style

struct VibeCardModifier: ViewModifier {
    var radius: CGFloat = VibeTheme.radiusLarge

    func body(content: Content) -> some View {
        content
            .background(VibeTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
    }
}

extension View {
    func vibeCard(radius: CGFloat = VibeTheme.radiusLarge) -> some View {
        modifier(VibeCardModifier(radius: radius))
    }
}

// MARK: - Glass Card Style

struct VibeGlassCardModifier: ViewModifier {
    var radius: CGFloat = VibeTheme.radiusLarge

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
    }
}

extension View {
    func vibeGlassCard(radius: CGFloat = VibeTheme.radiusLarge) -> some View {
        modifier(VibeGlassCardModifier(radius: radius))
    }
}

// MARK: - Shadow Elevation Scale

enum VibeShadowLevel {
    case sm, md, lg, xl
}

struct VibeShadowModifier: ViewModifier {
    let level: VibeShadowLevel

    func body(content: Content) -> some View {
        switch level {
        case .sm:
            content
                .shadow(color: .black.opacity(0.03), radius: 2, y: 1)
        case .md:
            content
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        case .lg:
            content
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        case .xl:
            content
                .shadow(color: .black.opacity(0.07), radius: 12, y: 6)
        }
    }
}

extension View {
    func vibeShadow(_ level: VibeShadowLevel) -> some View {
        modifier(VibeShadowModifier(level: level))
    }
}

// MARK: - Elevated Shadow (legacy compat)

struct ElevatedShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
    }
}

extension View {
    func elevatedShadow() -> some View {
        modifier(ElevatedShadowModifier())
    }
}

// MARK: - Shimmer Loading Effect

struct VibeShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.3),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func vibeShimmer() -> some View {
        modifier(VibeShimmerModifier())
    }
}

// MARK: - Press Effect Button Style

struct VibePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func vibePressEffect() -> some View {
        buttonStyle(VibePressStyle())
    }
}

// MARK: - Button Styles

enum VibeButtonVariant {
    case primary    // Brand gradient fill
    case secondary  // Outline with accent
    case tertiary   // Text-only
}

struct VibeButtonModifier: ViewModifier {
    let variant: VibeButtonVariant

    func body(content: Content) -> some View {
        switch variant {
        case .primary:
            content
                .font(VibeTypography.titleSmall)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget)
                .background(VibeTheme.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous))
                .shadow(color: VibeTheme.accent.opacity(0.3), radius: 8, y: 4)

        case .secondary:
            content
                .font(VibeTypography.titleSmall)
                .foregroundColor(VibeTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: VibeSpacing.minTouchTarget)
                .background(VibeTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                        .stroke(VibeTheme.accent.opacity(0.3), lineWidth: 1.5)
                )

        case .tertiary:
            content
                .font(VibeTypography.titleSmall)
                .foregroundColor(VibeTheme.accent)
                .frame(height: VibeSpacing.minTouchTarget)
        }
    }
}

extension View {
    func vibeButton(_ variant: VibeButtonVariant) -> some View {
        modifier(VibeButtonModifier(variant: variant))
    }
}

// MARK: - Section Header

extension View {
    func vibeSectionHeader() -> some View {
        self
            .font(VibeTypography.captionLarge)
            .foregroundColor(VibeTheme.textSecondary)
    }
}

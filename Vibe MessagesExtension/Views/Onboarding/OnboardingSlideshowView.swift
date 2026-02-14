import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let gradient: [Color]
}

struct OnboardingSlideshowView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                // Slide 1: Welcome
                OnboardingSlideOne(onContinue: {
                    VibeHaptic.light()
                    withAnimation(VibeAnimation.snappy) {
                        currentPage = 1
                    }
                })
                .tag(0)

                // Slide 2: Aura Economy & Betting
                OnboardingFeatureSlide(
                    title: "Earn Aura",
                    description: "Bet on your squad, spill tea, and climb the leaderboard.",
                    icon: "sparkles",
                    gradient: VibeTheme.auraGradient,
                    onContinue: {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.snappy) {
                            currentPage = 2
                        }
                    }
                )
                .tag(1)

                // Slide 3: Story Rings & Squad
                OnboardingFeatureSlide(
                    title: "Track the Squad",
                    description: "See who's the MVP, who's ghosting, and check everyone's live status.",
                    icon: "person.3.fill",
                    gradient: VibeTheme.brandGradient,
                    onContinue: {
                        VibeHaptic.success()
                        withAnimation(VibeAnimation.smooth) {
                            appState.completeOnboarding()
                        }
                    }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)

            // Page indicators
            VStack {
                Spacer()
                HStack(spacing: VibeSpacing.xs) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.4))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(VibeAnimation.snappy, value: currentPage)
                    }
                }
                .padding(.bottom, 100)
            }

            // Skip button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.smooth) {
                            appState.completeOnboarding()
                        }
                    } label: {
                        Text("Skip")
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(.white)
                            .padding(.horizontal, VibeSpacing.md)
                            .padding(.vertical, VibeSpacing.xs)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Feature Slide

struct OnboardingFeatureSlide: View {
    let title: String
    let description: String
    let icon: String
    let gradient: LinearGradient
    let onContinue: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            gradient
                .opacity(0.85)
                .ignoresSafeArea()

            Color.black.opacity(0.3).ignoresSafeArea()

            VStack(spacing: VibeSpacing.xl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: icon)
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                }
                .scaleEffect(isVisible ? 1.0 : 0.8)
                .opacity(isVisible ? 1 : 0)

                VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                    Text(title)
                        .font(VibeTypography.displayLarge)
                        .foregroundColor(.white)

                    Text(description)
                        .font(VibeTypography.bodyLarge)
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VibeSpacing.xl)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)

                // Continue button
                Button(action: onContinue) {
                    HStack(spacing: VibeSpacing.sm) {
                        Text("Continue")
                            .font(VibeTypography.titleMedium)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.md)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .vibeShadow(.lg)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xl)
                .padding(.bottom, VibeSpacing.xxxl + VibeSpacing.lg)
            }
        }
        .onAppear {
            withAnimation(VibeAnimation.smooth.delay(0.2)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

// Legacy slide view kept for compatibility
struct OnboardingLegacySlideView: View {
    let title: String
    let description: String
    let icon: String
    let gradient: [Color]
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.8)
                .ignoresSafeArea()

            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: VibeSpacing.xl) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(radius: 10)

                VStack(alignment: .leading, spacing: VibeSpacing.sm) {
                    Text(title)
                        .font(VibeTypography.displayLarge)
                        .foregroundColor(.white)

                    Text(description)
                        .font(VibeTypography.bodyLarge)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VibeSpacing.xl)

                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
                            .font(VibeTypography.titleMedium)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, VibeSpacing.md)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xl)
                .padding(.bottom, VibeSpacing.xxxl + VibeSpacing.lg)
            }
        }
    }
}

struct SlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: VibeSpacing.xxxl) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: slide.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .opacity(0.1)

                Image(systemName: slide.icon)
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: slide.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: VibeSpacing.md) {
                Text(slide.title)
                    .font(VibeTypography.displayMedium)
                    .multilineTextAlignment(.center)

                Text(slide.description)
                    .font(VibeTypography.bodyLarge)
                    .foregroundColor(VibeTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VibeSpacing.xxxl)
            }
        }
    }
}

#Preview {
    OnboardingSlideshowView()
        .environmentObject(AppState())
}

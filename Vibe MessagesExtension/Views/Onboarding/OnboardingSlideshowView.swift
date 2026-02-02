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
                // Slide 1: The New Video Background Slide
                OnboardingSlideOne(onContinue: {
                    withAnimation {
                        currentPage = 1
                    }
                })
                .tag(0)
                
                // Slide 2: Daily Drop (Placeholder for now, can be redesigned later)
                OnboardingLegacySlideView(
                    title: "Daily Drop Shuffles",
                    description: "Shake things up! Roll the dice for daily group challenges and prompts.",
                    icon: "die.face.5.fill",
                    gradient: [.blue, .cyan],
                    onContinue: {
                        withAnimation {
                            currentPage = 2
                        }
                    }
                )
                .tag(1)
                
                // Slide 3: Track the Squad
                OnboardingLegacySlideView(
                    title: "Track the Squad",
                    description: "See who's the MVP, who's ghosting, and check everyone's live status.",
                    icon: "chart.bar.fill",
                    gradient: [.orange, .red],
                    onContinue: {
                        withAnimation {
                            appState.completeOnboarding()
                        }
                    }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)
            
            // Global Skip Button (Top Right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            appState.completeOnboarding()
                        }
                    } label: {
                        Text("Skip")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                }
                Spacer()
            }
        }
    }
}

// Helper to use existing slide data in the new full-screen style
struct OnboardingLegacySlideView: View {
    let title: String
    let description: String
    let icon: String
    let gradient: [Color]
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.8)
                .ignoresSafeArea()
            
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(radius: 10)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                
                // Action Button
                Button(action: onContinue) {
                    HStack {
                        Text("Continue")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
            }
        }
    }
}

struct SlideView: View {
    let slide: OnboardingSlide
    
    var body: some View {
        VStack(spacing: 40) {
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
            
            VStack(spacing: 16) {
                Text(slide.title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(slide.description)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    OnboardingSlideshowView()
        .environmentObject(AppState())
}

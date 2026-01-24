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
    
    let slides = [
        OnboardingSlide(
            title: "Share the Vibe",
            description: "Post photos, videos, or just 'Spill the Tea'. Keep your circle in the loop.",
            icon: "camera.shutter.button.fill",
            gradient: [.pink, .purple]
        ),
        OnboardingSlide(
            title: "Daily Drop Shuffles",
            description: "Shake things up! Roll the dice for daily group challenges and prompts.",
            icon: "die.face.5.fill",
            gradient: [.blue, .cyan]
        ),
        OnboardingSlide(
            title: "Track the Squad",
            description: "See who's the MVP, who's ghosting, and check everyone's live status.",
            icon: "chart.bar.fill",
            gradient: [.orange, .red]
        )
    ]
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation {
                            appState.completeOnboarding()
                        }
                    } label: {
                        Text("Skip")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
                .padding()
                
                TabView(selection: $currentPage) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        SlideView(slide: slides[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                if currentPage == slides.count - 1 {
                    Button {
                        withAnimation {
                            appState.completeOnboarding()
                        }
                    } label: {
                        Text("Get Started")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                            .padding(.horizontal, 40)
                            .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Button {
                        withAnimation {
                            currentPage += 1
                        }
                    } label: {
                        Text("Next")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
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

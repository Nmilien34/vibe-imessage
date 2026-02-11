import SwiftUI
import MapKit

struct ETAComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var selectedStatus: String?

    let options: [(String, Color)] = [
        ("Leaving Now", .blue),
        ("5 Mins Out", .orange),
        ("Here", .green),
        ("Stuck in Traffic", .red)
    ]

    var body: some View {
        VStack(spacing: VibeSpacing.xl) {
            // Map Preview
            ZStack {
                RoundedRectangle(cornerRadius: VibeTheme.radiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "map.fill")
                            .font(.system(size: 80))
                            .foregroundColor(VibeTheme.textTertiary)
                    )

                if let status = selectedStatus {
                    VStack {
                        Text(status)
                            .font(VibeTypography.displaySmall)
                            .foregroundColor(.white)
                            .padding(VibeSpacing.md)
                            .background(.ultraThinMaterial)
                            .continuousCorner(VibeTheme.radiusMedium)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 250)
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VibeSpacing.md) {
                ForEach(options, id: \.0) { option, color in
                    Button {
                        VibeHaptic.selection()
                        withAnimation(VibeAnimation.bouncy) {
                            selectedStatus = option
                        }
                    } label: {
                        Text(option)
                            .font(VibeTypography.titleSmall)
                            .foregroundColor(selectedStatus == option ? .white : VibeTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(selectedStatus == option ? color : Color.clear)
                            .background(.ultraThinMaterial)
                            .continuousCorner(VibeTheme.radiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: VibeTheme.radiusMedium, style: .continuous)
                                    .stroke(color, lineWidth: 2)
                            )
                    }
                    .buttonStyle(VibePressStyle())
                }
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            Spacer()

            Button {
                VibeHaptic.success()
                Task { await shareETA() }
            } label: {
                Text("Share Status")
                    .vibeButton(.primary)
            }
            .buttonStyle(VibePressStyle())
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .disabled(selectedStatus == nil)
            .opacity(selectedStatus == nil ? 0.5 : 1.0)
        }
        .padding(.top, VibeSpacing.md)
    }

    private func shareETA() async {
        guard let status = selectedStatus else { return }
        do {
            let vibe = try await appState.createVibe(
                type: .eta,
                etaStatus: status,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .eta, contextText: status)
            appState.dismissComposer()
        } catch {
            print("Error sharing ETA: \(error)")
        }
    }
}

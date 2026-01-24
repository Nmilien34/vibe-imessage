import SwiftUI
import MapKit

struct ETAComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var selectedStatus: String?
    
    let options = [
        ("Leaving Now 🏃‍♂️", Color.blue),
        ("5 Mins Out 🚗", Color.orange),
        ("Here 📍", Color.green),
        ("Stuck in Traffic 🛑", Color.red)
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Map Preview Placeholder
            ZStack {
                // Mock Map Background
                Rectangle()
                    .fill(Color(.systemGray6))
                    .overlay(
                        Image(systemName: "map.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.3))
                    )
                    .cornerRadius(24)
                
                if let status = selectedStatus {
                    VStack {
                        Text(status)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(height: 250)
            .padding(.horizontal)
            
            // Options Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(options, id: \.0) { option, color in
                    Button {
                        withAnimation(.spring()) {
                            selectedStatus = option
                        }
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(selectedStatus == option ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(selectedStatus == option ? color : Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(color, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Share Button
            Button {
                Task {
                    await shareETA()
                }
            } label: {
                Text("Share Status 📍")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(selectedStatus == nil)
            .opacity(selectedStatus == nil ? 0.5 : 1.0)
        }
        .padding(.top, 16)
    }
    
    private func shareETA() async {
        guard let status = selectedStatus else { return }
        do {
            try await appState.createVibe(
                type: .eta,
                etaStatus: status,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            print("Error sharing ETA: \(error)")
        }
    }
}

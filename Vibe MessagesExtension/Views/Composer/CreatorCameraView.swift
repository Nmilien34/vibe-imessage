//
//  CreatorCameraView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI
import PhotosUI

enum CameraMode: String, CaseIterable, Identifiable {
    case normal = "NORMAL"
    case locked = "LOCKED"
    case loop = "LOOP"
    
    var id: String { self.rawValue }
}

struct CreatorCameraView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState // To access dismissComposer via appState if needed
    
    // Config
    var initialMode: CameraMode = .normal
    
    // State
    @State private var selectedMode: CameraMode
    @State private var isRecording = false
    @State private var showPrompter = false
    @State private var promptText = "Show us your fridge."
    @State private var timerString = "00:00 / 00:15"
    
    // Binding for Media Picker
    @Binding var selectedItem: PhotosPickerItem?
    
    // Mock Data for "Upload" button (last photo)
    @State private var lastPhoto: Image? = Image(systemName: "photo")
    
    init(initialLocked: Bool = false, selectedItem: Binding<PhotosPickerItem?>) {
        _selectedMode = State(initialValue: initialLocked ? .locked : .normal)
        _selectedItem = selectedItem
    }
    
    var body: some View {
        ZStack {
            // Layer 1: Camera Feed (Mock)
            Color.black
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.3))
                )
            
            // Layer 2: UI Overlay
            VStack {
                // A. Header
                headerView
                
                Spacer()
                
                // B. Prompter (Center)
                if showPrompter {
                    Text(promptText)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // C. Footer controls
                footerView
            }
            .padding(.top, 44) // approximate safe area if needed, or rely on SafeArea
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            // Close Button
            Button {
                // Dismiss logic
                if appState.isComposerPresented {
                    appState.dismissComposer()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .shadow(radius: 4)
            
            Spacer()
            
            // Timer Capsule
            Text(timerString)
                .font(.system(.subheadline, design: .rounded)) // Monospaced Digit not directly available in standard Font modifier easily without UIFont, trying standard first
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.5))
                .clipShape(Capsule())
            
            Spacer()
            
            // Camera Tools (Flash & Flip)
            VStack(spacing: 12) {
                Button {
                    // Toggle Flash
                } label: {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Button {
                    // Flip Camera
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .shadow(radius: 4)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
        VStack(spacing: 24) {
            // 1. Mode Selector
            HStack(spacing: 24) {
                ForEach(CameraMode.allCases) { mode in
                    Button {
                        withAnimation(.spring()) {
                            selectedMode = mode
                        }
                        // Trigger haptic
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred()
                        
                    } label: {
                        VStack(spacing: 4) {
                            Text(mode.rawValue)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(selectedMode == mode ? .bold : .medium)
                                .foregroundColor(.white)
                                .opacity(selectedMode == mode ? 1.0 : 0.5)
                            
                            if selectedMode == mode {
                                Circle()
                                    .fill(Color.yellow) // "glowing dot", maybe yellow or white with glow
                                    .frame(width: 4, height: 4)
                                    .shadow(color: .yellow, radius: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .shadow(radius: 4)
            
            // 2. Action Row
            HStack(spacing: 40) {
                // Left: Dice / Prompts
                Button {
                    withAnimation {
                        showPrompter.toggle()
                        promptText = "Show us your fridge." // Logic to Randomize later
                    }
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: "die.face.5")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                
                // Center: Shutter Button
                ZStack {
                    // Outer Ring
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 4)
                        .frame(width: 76, height: 76) // Slightly larger to contain 70px inner
                        .shadow(radius: 4)
                    
                    // Inner Circle (Shutter)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.red, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isRecording ? 70 : 60, height: isRecording ? 70 : 60)
                        .scaleEffect(isRecording ? 1.0 : 0.9) // Additional scale visual
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
                        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
                            withAnimation {
                                isRecording = pressing
                            }
                            if pressing {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                        }) {
                            // Action on release/complete
                        }
                    
                    // Progress Bar (Mock)
                    if isRecording {
                        Circle()
                            .trim(from: 0, to: 0.33) // Mock progress
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 76, height: 76)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 15), value: isRecording) // Mock timer
                    }
                }
                
                // Right: Upload (Gallery)
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.videos, .images])) {
                    if let image = lastPhoto {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .shadow(radius: 4)
                    } else {
                        // Fallback
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }
}

#Preview {
    CreatorCameraView(selectedItem: .constant(nil))
        .environmentObject(AppState())
}

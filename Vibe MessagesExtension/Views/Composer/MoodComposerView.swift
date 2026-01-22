//
//  MoodComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct MoodComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var selectedEmoji: String?
    @State private var customText = ""
    @FocusState private var isFocused: Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("How are you feeling?")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top)
            
            if let selected = selectedEmoji {
                // Selected State
                VStack(spacing: 32) {
                    Text(selected)
                        .font(.system(size: 100))
                        .onTapGesture {
                            withAnimation {
                                selectedEmoji = nil
                            }
                        }
                    
                    TextField("Add a note (optional)", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await shareMood()
                        }
                    } label: {
                        Text("Share Mood")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Button("Choose Different Mood") {
                        withAnimation {
                            selectedEmoji = nil
                        }
                    }
                    .padding(.top)
                }
            } else {
                // Picker State
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Mood.presets, id: \.emoji) { preset in
                            VStack {
                                Text(preset.emoji)
                                    .font(.system(size: 50))
                                Text(preset.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .onTapGesture {
                                withAnimation {
                                    selectedEmoji = preset.emoji
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
    }
    
    private func shareMood() async {
        guard let emoji = selectedEmoji else { return }
        
        do {
            let mood = Mood(emoji: emoji, text: customText.isEmpty ? nil : customText)
            try await appState.createVibe(
                type: .mood,
                mood: mood,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            print("Error sharing mood: \(error)")
        }
    }
}

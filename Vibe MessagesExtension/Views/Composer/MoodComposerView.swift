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
        VStack(spacing: VibeSpacing.xl) {
            Text("How are you feeling?")
                .font(VibeTypography.titleLarge)
                .foregroundColor(VibeTheme.textPrimary)
                .padding(.top, VibeSpacing.md)

            if let selected = selectedEmoji {
                VStack(spacing: VibeSpacing.xxl) {
                    Text(selected)
                        .font(.system(size: 100))
                        .onTapGesture {
                            VibeHaptic.light()
                            withAnimation(VibeAnimation.bouncy) {
                                selectedEmoji = nil
                            }
                        }

                    TextField("Add a note (optional)", text: $customText)
                        .font(VibeTypography.bodyLarge)
                        .padding(VibeSpacing.md)
                        .background(.ultraThinMaterial)
                        .continuousCorner(VibeTheme.radiusMedium)
                        .focused($isFocused)
                        .padding(.horizontal, VibeSpacing.screenHorizontal)

                    Button {
                        VibeHaptic.success()
                        Task { await shareMood() }
                    } label: {
                        Text("Share Mood")
                            .vibeButton(.primary)
                    }
                    .buttonStyle(VibePressStyle())
                    .padding(.horizontal, VibeSpacing.screenHorizontal)

                    Button("Choose Different Mood") {
                        VibeHaptic.light()
                        withAnimation(VibeAnimation.bouncy) {
                            selectedEmoji = nil
                        }
                    }
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.accent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: VibeSpacing.lg) {
                        ForEach(Mood.presets, id: \.emoji) { preset in
                            VStack(spacing: VibeSpacing.xxs) {
                                Text(preset.emoji)
                                    .font(.system(size: 50))
                                Text(preset.label)
                                    .font(VibeTypography.captionSmall)
                                    .foregroundColor(VibeTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, VibeSpacing.md)
                            .background(.ultraThinMaterial)
                            .continuousCorner(VibeTheme.radiusMedium)
                            .onTapGesture {
                                VibeHaptic.selection()
                                withAnimation(VibeAnimation.bouncy) {
                                    selectedEmoji = preset.emoji
                                }
                            }
                        }
                    }
                    .padding(.horizontal, VibeSpacing.screenHorizontal)
                }
            }

            Spacer()
        }
    }

    private func shareMood() async {
        guard let emoji = selectedEmoji else { return }
        do {
            let mood = Mood(emoji: emoji, text: customText.isEmpty ? nil : customText)
            let vibe = try await appState.createVibe(
                type: .mood,
                mood: mood,
                isLocked: isLocked
            )
            let moodContext = customText.isEmpty ? emoji : "\(emoji)|\(customText)"
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .mood, contextText: moodContext)
            appState.dismissComposer()
        } catch {
            print("Error sharing mood: \(error)")
        }
    }
}

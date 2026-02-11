//
//  PollComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct PollComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool

    @State private var question = ""
    @State private var options = ["", ""]
    @FocusState private var focusedField: Int?

    var body: some View {
        ScrollView {
            VStack(spacing: VibeSpacing.xl) {
                VStack(alignment: .leading, spacing: VibeSpacing.xs) {
                    Text("QUESTION")
                        .vibeSectionHeader()
                    TextField("Ask something...", text: $question)
                        .font(VibeTypography.bodyLarge)
                        .padding(VibeSpacing.md)
                        .background(.ultraThinMaterial)
                        .continuousCorner(VibeTheme.radiusMedium)
                        .focused($focusedField, equals: -1)
                }

                VStack(alignment: .leading, spacing: VibeSpacing.md) {
                    Text("OPTIONS")
                        .vibeSectionHeader()

                    ForEach(Array(options.indices), id: \.self) { index in
                        PollOptionRow(
                            text: Binding<String>(
                                get: {
                                    guard options.indices.contains(index) else { return "" }
                                    return options[index]
                                },
                                set: { newValue in
                                    guard options.indices.contains(index) else { return }
                                    options[index] = newValue
                                }
                            ),
                            index: index,
                            showRemove: options.count > 2,
                            onRemove: {
                                VibeHaptic.light()
                                withAnimation(VibeAnimation.snappy) {
                                    if options.indices.contains(index) {
                                        options.remove(at: index)
                                    }
                                }
                            }
                        )
                        .focused($focusedField, equals: index)
                    }

                    if options.count < 4 {
                        Button {
                            VibeHaptic.light()
                            withAnimation(VibeAnimation.snappy) {
                                options.append("")
                            }
                        } label: {
                            HStack(spacing: VibeSpacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Option")
                                    .font(VibeTypography.bodyMedium)
                            }
                            .foregroundColor(VibeTheme.accent)
                        }
                    }
                }

                Spacer(minLength: VibeSpacing.xxxl)

                Button {
                    VibeHaptic.success()
                    Task { await sharePoll() }
                } label: {
                    Text("Create Poll")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.5)
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)
            .padding(.top, VibeSpacing.md)
        }
        .onAppear {
            focusedField = -1
        }
    }

    private var isValid: Bool {
        !question.isEmpty && options.filter { !$0.isEmpty }.count >= 2
    }

    private func sharePoll() async {
        let validOptions = options.filter { !$0.isEmpty }
        let request = CreatePollRequest(question: question, options: validOptions)
        do {
            let vibe = try await appState.createVibe(
                type: .poll,
                poll: request,
                isLocked: isLocked
            )
            appState.sendVibeMessage(vibeId: vibe.id, isLocked: isLocked, vibeType: .poll, contextText: question)
            appState.dismissComposer()
        } catch {
            print("Error creating poll: \(error)")
        }
    }
}

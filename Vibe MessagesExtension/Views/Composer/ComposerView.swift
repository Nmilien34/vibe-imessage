//
//  ComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct ComposerView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedType: VibeType?
    @State private var isLocked = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                if let type = selectedType ?? appState.selectedVibeType {
                    typeComposer(for: type)
                } else {
                    typePickerView
                }
            }
            .navigationTitle(selectedType == nil ? "New Vibe" : selectedType!.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if selectedType != nil {
                            selectedType = nil
                        } else {
                            appState.dismissComposer()
                        }
                    }
                }
            }
        }
    }

    private var typePickerView: some View {
        VStack(spacing: 24) {
            Text("What's your vibe?")
                .font(.title2)
                .fontWeight(.semibold)

            // Type grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(VibeType.allCases, id: \.self) { type in
                    VibeTypeCard(type: type) {
                        withAnimation {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Lock toggle
            Toggle(isOn: $isLocked) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text("Lock this vibe")
                            .font(.headline)
                        Text("Others must post to unlock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private func typeComposer(for type: VibeType) -> some View {
        switch type {
        case .video:
            VideoComposerView(isLocked: isLocked)
        case .song:
            SongComposerView(isLocked: isLocked)
        case .battery:
            BatteryComposerView(isLocked: isLocked)
        case .mood:
            MoodComposerView(isLocked: isLocked)
        case .poll:
            PollComposerView(isLocked: isLocked)
        }
    }
}

// MARK: - Vibe Type Card
struct VibeTypeCard: View {
    let type: VibeType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(type.color)
                }

                Text(type.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ComposerView()
        .environmentObject(AppState())
}

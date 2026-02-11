import SwiftUI

struct AddReminderSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var step = 1
    @State private var selectedType: ReminderType?
    @State private var emoji: String = ""
    @State private var title: String = ""
    @State private var selectedDate: Date = Date().addingTimeInterval(86400)
    @State private var showDatePicker = false
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                VibeTheme.groupedBackground
                    .edgesIgnoringSafeArea(.all)

                if step == 1 {
                    typePickerView
                        .transition(.move(edge: .leading))
                } else {
                    detailsView
                        .transition(.move(edge: .trailing))
                }
            }
            .navigationTitle(step == 1 ? "New Reminder" : "Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .animation(VibeAnimation.snappy, value: step)
        }
    }

    // MARK: - Step 1: Type Picker

    private var typePickerView: some View {
        VStack(spacing: VibeSpacing.lg) {
            Text("What's coming up?")
                .font(VibeTypography.titleMedium)
                .padding(.top, VibeSpacing.lg)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: VibeSpacing.lg), GridItem(.flexible(), spacing: VibeSpacing.lg)], spacing: VibeSpacing.lg) {
                ForEach(ReminderType.allCases, id: \.self) { type in
                    TypeCard(type: type, isSelected: selectedType == type) {
                        withAnimation(VibeAnimation.bouncy) {
                            selectedType = type
                            emoji = type.emoji
                        }
                        VibeHaptic.selection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { step = 2 }
                        }
                    }
                }
            }
            .padding(.horizontal, VibeSpacing.lg)

            Spacer()
        }
    }

    // MARK: - Step 2: Details

    private var detailsView: some View {
        ScrollView {
            VStack(spacing: VibeSpacing.xxl) {
                // Emoji display
                Button {
                    // Could open emoji picker
                } label: {
                    Text(emoji)
                        .font(.system(size: 56))
                        .frame(width: 90, height: 90)
                        .background(
                            Circle()
                                .fill((selectedType?.color ?? VibeTheme.accent).opacity(0.15))
                        )
                }
                .padding(.top, VibeSpacing.lg)

                // Title
                TextField("What's happening?", text: $title)
                    .font(VibeTypography.titleSmall)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(VibeTheme.cardBackground)
                    .continuousCorner(VibeTheme.radiusMedium)
                    .vibeShadow(.sm)
                    .padding(.horizontal, VibeSpacing.lg)

                // Quick date buttons
                VStack(spacing: VibeSpacing.md) {
                    Text("WHEN?")
                        .font(VibeTypography.overline)
                        .foregroundColor(VibeTheme.textTertiary)

                    HStack(spacing: VibeSpacing.xs) {
                        QuickDateButton(label: "Tomorrow", isSelected: isTomorrow) {
                            selectedDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400 + 43200)
                            showDatePicker = false
                        }
                        QuickDateButton(label: "This Weekend", isSelected: isThisWeekend) {
                            selectedDate = nextWeekend()
                            showDatePicker = false
                        }
                        QuickDateButton(label: "Next Week", isSelected: isNextWeek) {
                            selectedDate = nextWeekStart()
                            showDatePicker = false
                        }
                    }

                    Button {
                        withAnimation(VibeAnimation.snappy) { showDatePicker.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Pick Date")
                        }
                        .font(VibeTypography.captionLarge)
                        .foregroundColor(showDatePicker ? .white : VibeTheme.textPrimary)
                        .padding(.horizontal, VibeSpacing.lg)
                        .padding(.vertical, VibeSpacing.xs)
                        .background(showDatePicker ? (selectedType?.color ?? VibeTheme.accent) : VibeTheme.cardBackground)
                        .continuousCorner(VibeTheme.radiusSmall)
                        .vibeShadow(.sm)
                    }

                    if showDatePicker {
                        DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(VibeTheme.cardBackground)
                            .continuousCorner(VibeTheme.radiusMedium)
                            .padding(.horizontal, VibeSpacing.lg)
                    }
                }

                // Add button
                Button {
                    VibeHaptic.success()
                    saveReminder()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add \u{1F3AF}")
                                .font(VibeTypography.titleSmall)
                        }
                    }
                    .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding(.horizontal, VibeSpacing.lg)

                // Back button
                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Back")
                        .font(VibeTypography.bodySmall)
                        .foregroundColor(VibeTheme.textTertiary)
                }
                .padding(.bottom, VibeSpacing.lg)
            }
        }
    }

    // MARK: - Helpers

    private var isTomorrow: Bool {
        let tomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        return Calendar.current.isDate(selectedDate, inSameDayAs: tomorrow)
    }

    private var isThisWeekend: Bool {
        let weekend = nextWeekend()
        return Calendar.current.isDate(selectedDate, inSameDayAs: weekend)
    }

    private var isNextWeek: Bool {
        let next = nextWeekStart()
        return Calendar.current.isDate(selectedDate, inSameDayAs: next)
    }

    private func nextWeekend() -> Date {
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 7 // Saturday
        components.hour = 12
        var saturday = calendar.date(from: components) ?? today.addingTimeInterval(86400 * 3)
        if saturday <= today {
            saturday = saturday.addingTimeInterval(7 * 86400)
        }
        return saturday
    }

    private func nextWeekStart() -> Date {
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        components.hour = 12
        var monday = calendar.date(from: components) ?? today.addingTimeInterval(86400 * 5)
        if monday <= today {
            monday = monday.addingTimeInterval(7 * 86400)
        }
        return monday
    }

    private func saveReminder() {
        guard let type = selectedType else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        isSaving = true
        Task {
            await appState.createReminder(
                type: type,
                emoji: emoji,
                title: trimmedTitle,
                date: selectedDate
            )
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        }
    }
}

// MARK: - Subviews

struct TypeCard: View {
    let type: ReminderType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: VibeSpacing.md) {
                Text(type.emoji)
                    .font(.system(size: 40))
                Text(type.displayName)
                    .font(VibeTypography.titleSmall)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                LinearGradient(colors: type.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .continuousCorner(VibeTheme.radiusLarge)
            .scaleEffect(isSelected ? 0.92 : 1.0)
            .vibeShadow(isSelected ? .sm : .lg)
        }
        .buttonStyle(VibePressStyle())
    }
}

struct QuickDateButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            VibeHaptic.selection()
            onTap()
        }) {
            Text(label)
                .font(VibeTypography.captionSmall)
                .foregroundColor(isSelected ? .white : VibeTheme.textPrimary)
                .padding(.horizontal, VibeSpacing.md)
                .padding(.vertical, VibeSpacing.xs)
                .background(isSelected ? VibeTheme.accent : VibeTheme.cardBackground)
                .continuousCorner(VibeTheme.radiusSmall)
                .vibeShadow(.sm)
        }
    }
}

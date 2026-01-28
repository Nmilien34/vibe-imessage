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
                Color(red: 0.96, green: 0.96, blue: 0.97)
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
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
        }
    }

    // MARK: - Step 1: Type Picker

    private var typePickerView: some View {
        VStack(spacing: 20) {
            Text("What's coming up?")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.top, 20)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(ReminderType.allCases, id: \.self) { type in
                    TypeCard(type: type, isSelected: selectedType == type) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedType = type
                            emoji = type.emoji
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation { step = 2 }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 2: Details

    private var detailsView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Emoji display
                Button {
                    // Could open emoji picker; for now just cycles default
                } label: {
                    Text(emoji)
                        .font(.system(size: 56))
                        .frame(width: 90, height: 90)
                        .background(
                            Circle()
                                .fill((selectedType?.color ?? .blue).opacity(0.15))
                        )
                }
                .padding(.top, 16)

                // Title
                TextField("What's happening?", text: $title)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    .padding(.horizontal, 20)

                // Quick date buttons
                VStack(spacing: 12) {
                    Text("WHEN?")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.gray)

                    HStack(spacing: 10) {
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
                        withAnimation { showDatePicker.toggle() }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Pick Date")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(showDatePicker ? .white : .primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(showDatePicker ? (selectedType?.color ?? .blue) : Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.04), radius: 3)
                    }

                    if showDatePicker {
                        DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                    }
                }

                // Add button
                Button {
                    saveReminder()
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Add \u{1F3AF}")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: selectedType?.gradient ?? [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: (selectedType?.color ?? .blue).opacity(0.3), radius: 8, y: 4)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                .padding(.horizontal, 20)

                // Back button
                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Back")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 20)
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
            VStack(spacing: 12) {
                Text(type.emoji)
                    .font(.system(size: 40))
                Text(type.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .background(
                LinearGradient(colors: type.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(24)
            .scaleEffect(isSelected ? 0.92 : 1.0)
            .shadow(color: type.color.opacity(0.3), radius: isSelected ? 2 : 8, y: isSelected ? 1 : 4)
        }
    }
}

struct QuickDateButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 3)
        }
    }
}

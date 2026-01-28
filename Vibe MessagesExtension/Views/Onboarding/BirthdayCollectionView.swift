import SwiftUI
import Contacts

struct BirthdayCollectionView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading = true
    @State private var selectedMonth = 1
    @State private var selectedDay = 1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if isLoading {
                loadingView
            } else {
                manualInputView
            }
        }
        .task {
            await resolveBirthdayFromContacts()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Setting up your profile...")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Manual Input View

    private var manualInputView: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("When's your birthday? \u{1F382}")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Picker("Month", selection: $selectedMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker("Day", selection: $selectedDay) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    appState.saveBirthday(month: selectedMonth, day: selectedDay)
                } label: {
                    Text("Continue")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                }
                .padding(.horizontal, 40)

                Button {
                    appState.skipBirthday()
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Contact Resolution

    private func resolveBirthdayFromContacts() async {
        let store = CNContactStore()

        do {
            let granted = try await store.requestAccess(for: .contacts)
            guard granted else {
                showManualInput()
                return
            }

            let keysToFetch: [CNKeyDescriptor] = [CNContactBirthdayKey as CNKeyDescriptor]

            // Attempt to find the user's own contact card ("me" card)
            // Search by the user's first name from Apple Sign In as a heuristic
            if let firstName = appState.userFirstName, !firstName.isEmpty {
                let predicate = CNContact.predicateForContacts(matchingName: firstName)
                let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
                for contact in contacts {
                    if let birthday = contact.birthday,
                       let month = birthday.month,
                       let day = birthday.day {
                        await MainActor.run {
                            appState.saveBirthday(month: month, day: day)
                        }
                        return
                    }
                }
            }
        } catch {
            print("Contacts access error: \(error)")
        }

        showManualInput()
    }

    @MainActor
    private func showManualInput() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }
}

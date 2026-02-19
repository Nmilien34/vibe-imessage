import SwiftUI
import Contacts
import CryptoKit

struct BirthdayCollectionView: View {
    @EnvironmentObject var appState: AppState

    @State private var isLoading = true
    @State private var selectedMonth = 1
    @State private var selectedDay = 1
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [VibeTheme.accent.opacity(0.15), VibeTheme.accentSecondary.opacity(0.1), VibeTheme.background],
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
            loadingTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled && isLoading {
                    await MainActor.run {
                        withAnimation(VibeAnimation.smooth) {
                            isLoading = false
                        }
                    }
                }
            }

            await resolveBirthdayFromContacts()
            loadingTask?.cancel()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: VibeSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(VibeTheme.accent)
            Text("Setting up your profile...")
                .font(VibeTypography.bodyLarge)
                .foregroundColor(VibeTheme.textSecondary)
        }
    }

    // MARK: - Manual Input View

    private var manualInputView: some View {
        VStack(spacing: VibeSpacing.xxl) {
            Spacer()

            Text("When's your birthday? \u{1F382}")
                .font(VibeTypography.displayMedium)
                .foregroundColor(VibeTheme.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: VibeSpacing.md) {
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
            .padding(.horizontal, VibeSpacing.xl)
            .vibeGlassCard(radius: VibeTheme.radiusMedium)
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            Spacer()

            VStack(spacing: VibeSpacing.sm) {
                Button {
                    VibeHaptic.success()
                    appState.saveBirthday(month: selectedMonth, day: selectedDay)
                } label: {
                    Text("Continue")
                        .vibeButton(.primary)
                }
                .buttonStyle(VibePressStyle())
                .padding(.horizontal, VibeSpacing.xxxl)

                Button {
                    VibeHaptic.light()
                    appState.skipBirthday()
                } label: {
                    Text("Skip")
                        .font(VibeTypography.bodyMedium)
                        .foregroundColor(VibeTheme.textSecondary)
                }
            }
            .padding(.bottom, VibeSpacing.xxxl)
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

            await syncContactNetwork(from: store)

            let keysToFetch: [CNKeyDescriptor] = [CNContactBirthdayKey as CNKeyDescriptor]

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

    private func syncContactNetwork(from store: CNContactStore) async {
        guard appState.isAuthenticated else { return }

        let keys: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var hashes = Set<String>()

        do {
            try store.enumerateContacts(with: request) { contact, stop in
                for emailValue in contact.emailAddresses {
                    if let hashed = hashEmail(emailValue.value as String) {
                        hashes.insert(hashed)
                    }
                }

                for phoneValue in contact.phoneNumbers {
                    if let hashed = hashPhone(phoneValue.value.stringValue) {
                        hashes.insert(hashed)
                    }
                }

                if hashes.count >= 5000 {
                    stop.pointee = true
                }
            }

            guard !hashes.isEmpty else { return }
            await appState.syncContactHashes(Array(hashes), replace: true, enableDiscovery: true)
        } catch {
            print("Contacts sync error: \(error)")
        }
    }

    private func hashEmail(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return "e:\(sha256Hex("email:\(normalized)"))"
    }

    private func hashPhone(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard !digits.isEmpty else { return nil }
        let normalized = trimmed.hasPrefix("+") ? "+\(digits)" : digits
        return "p:\(sha256Hex("phone:\(normalized)"))"
    }

    private func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    private func showManualInput() {
        guard isLoading else { return }
        withAnimation(VibeAnimation.smooth) {
            isLoading = false
        }
    }

    // MARK: - Helpers

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        return formatter.monthSymbols[month - 1]
    }
}

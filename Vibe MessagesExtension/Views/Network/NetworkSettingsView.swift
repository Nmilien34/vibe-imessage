import SwiftUI

struct NetworkSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isLoading = true

    private var groupUsers: [NetworkUser] {
        appState.networkUsers.filter { $0.source == "group" }
    }

    private var contactUsers: [NetworkUser] {
        appState.networkUsers.filter { $0.source == "contact" }
    }

    var body: some View {
        ZStack {
            VibeTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: VibeSpacing.sectionGap) {
                    networkHeader

                    discoveryToggle

                    if !groupUsers.isEmpty {
                        networkSection(title: "From Group Chats", icon: "bubble.left.and.bubble.right.fill", color: .teal, users: groupUsers)
                    }

                    if !contactUsers.isEmpty {
                        networkSection(title: "From Contacts", icon: "person.crop.circle.fill", color: VibeTheme.accentBlue, users: contactUsers)
                    }

                    if groupUsers.isEmpty && contactUsers.isEmpty && !isLoading {
                        emptyState
                    }

                    if isLoading {
                        ProgressView()
                            .tint(VibeTheme.textTertiary)
                            .padding(.vertical, VibeSpacing.xxxl)
                    }
                }
                .padding(.bottom, VibeSpacing.xxxl)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                VibeHaptic.light()
                appState.navigateToFeed()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VibeTheme.textPrimary)
                    .frame(width: VibeSpacing.minTouchTarget, height: VibeSpacing.minTouchTarget)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, VibeSpacing.screenHorizontal)
            .padding(.top, VibeSpacing.sm)
        }
        .task {
            await appState.loadAudienceGraph()
            isLoading = false
        }
    }

    // MARK: - Header

    private var networkHeader: some View {
        VStack(spacing: VibeSpacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 36))
                .foregroundColor(VibeTheme.accent)
                .padding(.bottom, VibeSpacing.xs)

            Text("Your Network")
                .font(VibeTypography.titleLarge)
                .foregroundColor(VibeTheme.textPrimary)

            let count = appState.audienceGraph?.mergedUserIds.count ?? 0
            Text("\(count) \(count == 1 ? "person" : "people") can see your content")
                .font(VibeTypography.captionLarge)
                .foregroundColor(VibeTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, VibeSpacing.xxxl + VibeSpacing.lg)
        .padding(.bottom, VibeSpacing.sm)
    }

    // MARK: - Discovery Toggle

    private var discoveryToggle: some View {
        Toggle(isOn: Binding(
            get: { appState.contactDiscoveryEnabled },
            set: { newValue in
                VibeHaptic.selection()
                Task { await appState.toggleContactDiscovery(enabled: newValue) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Contact Discovery")
                    .font(VibeTypography.bodyMedium)
                    .foregroundColor(VibeTheme.textPrimary)
                Text("Let contacts who also use Vibe see your challenges")
                    .font(VibeTypography.captionSmall)
                    .foregroundColor(VibeTheme.textSecondary)
            }
        }
        .tint(VibeTheme.accent)
        .padding(VibeSpacing.md)
        .background(VibeTheme.cardBackground)
        .continuousCorner(VibeTheme.radiusMedium)
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }

    // MARK: - Network Section

    private func networkSection(title: String, icon: String, color: Color, users: [NetworkUser]) -> some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            HStack(spacing: VibeSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(VibeTypography.overline)
                    .foregroundColor(VibeTheme.textTertiary)
                Spacer()
                Text("\(users.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(VibeTheme.textTertiary)
            }
            .padding(.horizontal, VibeSpacing.screenHorizontal)

            VStack(spacing: 0) {
                ForEach(users) { networkUser in
                    NetworkUserRow(networkUser: networkUser) {
                        VibeHaptic.medium()
                        Task { await appState.revokeVisibility(targetUserId: networkUser.id) }
                    }

                    if networkUser.id != users.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(VibeTheme.cardBackground)
            .continuousCorner(VibeTheme.radiusMedium)
            .padding(.horizontal, VibeSpacing.screenHorizontal)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: VibeSpacing.md) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(VibeTheme.textTertiary)
            Text("No network connections yet")
                .font(VibeTypography.titleSmall)
                .foregroundColor(VibeTheme.textSecondary)
            Text("Join group chats or enable contact discovery to grow your network")
                .font(VibeTypography.captionLarge)
                .foregroundColor(VibeTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VibeSpacing.xxxl)
        .padding(.horizontal, VibeSpacing.screenHorizontal)
    }
}

// MARK: - Network User Row

struct NetworkUserRow: View {
    let networkUser: NetworkUser
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: VibeSpacing.md) {
            if let picUrl = networkUser.user.profilePicture,
               let url = URL.httpURL(from: picUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                initialsCircle
            }

            Text(networkUser.user.displayName)
                .font(VibeTypography.bodyMedium)
                .foregroundColor(VibeTheme.textPrimary)

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VibeTheme.textTertiary)
                    .frame(width: 28, height: 28)
                    .background(VibeTheme.surfaceOverlay)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(VibeSpacing.md)
    }

    private var initialsCircle: some View {
        Circle()
            .fill(VibeTheme.surfaceOverlay)
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(networkUser.user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(VibeTheme.textPrimary)
            )
    }
}

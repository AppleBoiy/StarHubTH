import SwiftUI

/// `MainView`'s sidebar: search, the account/profile badge, the system-alerts badge, and
/// every tab section. Extracted from `MainView.body` (§5.5, ~150-line view budget) — this
/// alone was over 200 lines inline.
struct MainSidebarView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var profilesStore: ProfilesStore

    @Binding var currentTab: String
    @Binding var searchText: String

    @AppStorage("showDeveloperLogs") private var showDeveloperLogs: Bool = false
    @State private var isProfileHovered = false

    private func matchesSearch(_ text: String...) -> Bool {
        if searchText.isEmpty { return true }
        let lowerSearch = searchText.lowercased()
        return text.contains { $0.lowercased().contains(lowerSearch) }
    }

    private var activeProfile: ModProfile? {
        guard let activeProfileId = profilesStore.activeProfileId else { return nil }
        return profilesStore.modProfiles.first(where: { $0.id == activeProfileId })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(localizationStore.L(L10n.Main.search), text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // Account Section (macOS style profile)
            if matchesSearch(appEnvironment.steamUsername, localizationStore.L(L10n.Main.account)) {
                Button(action: { currentTab = "Home" }) {
                    HStack(spacing: 12) {
                        ZStack(alignment: .bottomTrailing) {
                            if let avatarPath = appEnvironment.steamAvatarPath, let nsImage = NSImage(contentsOfFile: avatarPath) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.gray)
                            }

                            if let activeProfile {
                                ZStack {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                                        )
                                    Text(String(activeProfile.name.prefix(1)).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 4, y: 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appEnvironment.steamUsername.isEmpty ? "Player" : appEnvironment.steamUsername)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Steam Account")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)

                            if let activeProfile {
                                Text("\(localizationStore.L(L10n.Profiles.titleFull)): \(activeProfile.name)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)
                            }
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(currentTab == "Home" ? Color.primary.opacity(0.1) : (isProfileHovered ? Color.primary.opacity(0.05) : Color.clear))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { isProfileHovered = $0 }
                .pointingHandCursor()
                .accessibilityIdentifier("sidebar-tab-Home")
            }

            let alertCount = modsStore.smapiErrors.count + modsStore.outOfDateMods.count
            if alertCount > 0 {
                Button(action: { currentTab = "Updates" }) {
                    HStack {
                        Text(modsStore.smapiErrors.isEmpty ? localizationStore.L(L10n.Main.softwareUpdate) : localizationStore.L(L10n.Main.systemAlerts))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(currentTab == "Updates" ? .white : .primary)
                        Spacer()
                        Text("\(alertCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(currentTab == "Updates" ? .blue : .white)
                            .frame(minWidth: 18, minHeight: 18)
                            .padding(.horizontal, 4)
                            .background(currentTab == "Updates" ? Color.white : Color.red)
                            .clipShape(Capsule())
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(currentTab == "Updates" ? Color.blue : Color.clear)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandCursor()
                .accessibilityIdentifier("sidebar-tab-Updates")
            }

            // Game Section
            VStack(alignment: .leading, spacing: 2) {
                SidebarSectionHeader(title: localizationStore.L(L10n.Main.gameManagement))
                if matchesSearch(localizationStore.L(L10n.Saves.saves)) {
                    SidebarNavItem(
                        icon: "folder.fill",
                        iconColor: .blue,
                        label: localizationStore.L(L10n.Saves.saves),
                        tab: "Saves",
                        currentTab: $currentTab
                    )
                }

                if matchesSearch(localizationStore.L(L10n.Mods.mods)) {
                    SidebarNavItem(
                        icon: "puzzlepiece.extension.fill",
                        iconColor: .purple,
                        label: localizationStore.L(L10n.Mods.mods),
                        tab: "Mods",
                        currentTab: $currentTab
                    )
                }

                if matchesSearch(localizationStore.L(L10n.Profiles.title)) {
                    SidebarNavItem(
                        icon: "person.2.fill",
                        iconColor: .orange,
                        label: localizationStore.L(L10n.Profiles.title),
                        tab: "Profiles",
                        currentTab: $currentTab
                    )
                }

                if matchesSearch(localizationStore.L(L10n.ModPacks.title)) {
                    SidebarNavItem(
                        icon: "shippingbox.fill",
                        iconColor: .teal,
                        label: localizationStore.L(L10n.ModPacks.title),
                        tab: "ModPacks",
                        currentTab: $currentTab
                    )
                }
            }

            // System & Settings Section
            VStack(alignment: .leading, spacing: 2) {
                SidebarSectionHeader(title: localizationStore.L(L10n.Main.system))

                if matchesSearch(localizationStore.L(L10n.Settings.settings)) {
                    SidebarNavItem(
                        icon: "gearshape.fill",
                        iconColor: .gray,
                        label: localizationStore.L(L10n.Settings.settings),
                        tab: "Settings",
                        currentTab: $currentTab
                    )
                }

                if matchesSearch(localizationStore.L(L10n.Main.appChangelog)) {
                    SidebarNavItem(
                        icon: "doc.text.magnifyingglass",
                        iconColor: .blue,
                        label: localizationStore.L(L10n.Main.appChangelog),
                        tab: "AppChangelog",
                        currentTab: $currentTab
                    )
                }
            }

            // Thai Hub Section
            VStack(alignment: .leading, spacing: 2) {
                SidebarSectionHeader(title: localizationStore.L(L10n.Main.online))
                if matchesSearch(localizationStore.L(L10n.ThaiHub.title)) {
                    SidebarNavItem(
                        icon: "globe.asia.australia.fill",
                        iconColor: .blue,
                        label: localizationStore.L(L10n.ThaiHub.title),
                        tab: "ThaiHub",
                        currentTab: $currentTab
                    )
                }
            }

            if showDeveloperLogs {
                if matchesSearch(localizationStore.L(L10n.Logs.logs)) {
                    SidebarNavItem(
                        icon: "terminal.fill",
                        iconColor: .black,
                        label: localizationStore.L(L10n.Logs.logs),
                        tab: "Logs",
                        currentTab: $currentTab
                    )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(minWidth: 240, idealWidth: 240, maxWidth: 240, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

import SwiftUI

struct MainView: View {
    // Phase 4.9 step 3: MainView is now the real composition root — StarHubTHViewModel is
    // gone, so store construction (previously its init()) lives here, sourcing every
    // service from DependencyContainer (finally used for its documented purpose) rather
    // than reaching for `.shared`/`Live*` directly.
    @StateObject private var localizationStore: LocalizationStore
    @StateObject private var logStore: LogStore
    @StateObject private var appEnvironment: AppEnvironment
    @StateObject private var thaiHubStore: ThaiHubStore
    @StateObject private var profilesStore: ProfilesStore
    @StateObject private var modPacksStore: ModPacksStore
    @StateObject private var savesStore: SavesStore
    @StateObject private var modsStore: ModsStore
    @StateObject private var alertStore: AlertStore
    @StateObject private var appCoordinator: AppCoordinator
    /// Same instance as `appEnvironment.smapiInstaller` — its own `@EnvironmentObject`
    /// since it publishes independently of `AppEnvironment`'s own `@Published` state.
    @StateObject private var smapiInstaller: SmapiInstaller

    @State private var currentTab: String = "Home"
    @State private var searchText: String = ""

    // History Management
    @State private var tabHistory: [String] = ["Home"]
    @State private var forwardHistory: [String] = []
    @State private var isNavigatingBackOrForward = false

    @AppStorage("appColorScheme") private var appColorScheme: String = "System"
    @AppStorage("showDeveloperLogs") private var showDeveloperLogs: Bool = false
    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"

    @State private var isProfileHovered = false

    init() {
        let container = DependencyContainer()
        let localizationStore = LocalizationStore()
        let logStore = LogStore()
        let appEnvironment = AppEnvironment(preferenceStoring: container.preferenceStoring, localization: localizationStore)
        let thaiHubStore = ThaiHubStore(localization: localizationStore)
        let profilesStore = ProfilesStore(profileStoring: container.profileStoring, localization: localizationStore)
        let modPacksStore = ModPacksStore(nexusAPIClient: container.nexusAPIClient, localization: localizationStore, logStore: logStore)
        let savesStore = SavesStore(saveStoring: container.saveStoring, saveNoteStoring: container.saveNoteStoring, filePicking: container.filePicking, localization: localizationStore)
        let modsStore = ModsStore(
            modScanning: container.modScanning,
            modInstalling: container.modInstalling,
            nexusAPIClient: container.nexusAPIClient,
            filePicking: container.filePicking,
            preferenceStoring: container.preferenceStoring,
            localization: localizationStore
        )
        let alertStore = AlertStore()
        let appCoordinator = AppCoordinator(
            localizationStore: localizationStore,
            logStore: logStore,
            thaiHubStore: thaiHubStore,
            profilesStore: profilesStore,
            modPacksStore: modPacksStore,
            savesStore: savesStore,
            modsStore: modsStore,
            appEnvironment: appEnvironment,
            alertStore: alertStore,
            filePicking: container.filePicking,
            preferenceStoring: container.preferenceStoring
        )

        _localizationStore = StateObject(wrappedValue: localizationStore)
        _logStore = StateObject(wrappedValue: logStore)
        _appEnvironment = StateObject(wrappedValue: appEnvironment)
        _thaiHubStore = StateObject(wrappedValue: thaiHubStore)
        _profilesStore = StateObject(wrappedValue: profilesStore)
        _modPacksStore = StateObject(wrappedValue: modPacksStore)
        _savesStore = StateObject(wrappedValue: savesStore)
        _modsStore = StateObject(wrappedValue: modsStore)
        _alertStore = StateObject(wrappedValue: alertStore)
        _appCoordinator = StateObject(wrappedValue: appCoordinator)
        _smapiInstaller = StateObject(wrappedValue: appEnvironment.smapiInstaller)

        // Startup orchestration — same sequence StarHubTHViewModel.init() used to run.
        appCoordinator.refresh()
        profilesStore.loadProfiles()
        if appEnvironment.steamUsername.isEmpty {
            appEnvironment.steamUsername = localizationStore.L(L10n.VM.defaultFarmerName)
        }
        logStore.log("StarHubTH started", level: .info)
    }

    private func matchesSearch(_ text: String...) -> Bool {
        if searchText.isEmpty { return true }
        let lowerSearch = searchText.lowercased()
        return text.contains { $0.lowercased().contains(lowerSearch) }
    }
    
    /// Extracted so the compiler doesn't have to re-infer this `first(where:)` lookup
    /// inside the account-badge view's already-large expression tree — needed to keep
    /// type-checking that section within a reasonable time budget.
    private var activeProfile: ModProfile? {
        guard let activeProfileId = profilesStore.activeProfileId else { return nil }
        return profilesStore.modProfiles.first(where: { $0.id == activeProfileId })
    }

    /// Extracted out of `body` — as one inline `Group { if ... }` chain this pushed the
    /// type-checker past its time budget once enough branches dropped their `vm:`
    /// argument (Phase 4.9 migration). A standalone `@ViewBuilder` property is its own
    /// smaller type-checking unit.
    @ViewBuilder
    private var detailContent: some View {
        if currentTab == "ModPacks" {
            ModPacksView()
        } else if currentTab == "Mods" {
            if let mod = modsStore.editingModConfig {
                ModConfigEditorView(mod: mod)
            } else if let mod = modsStore.viewingModDetails {
                ModDetailView(mod: mod)
            } else {
                ModListView()
            }
        } else if currentTab == "Saves" {
            if let save = savesStore.viewingSaveTimeline {
                SaveTimelineView(save: save)
            } else if let save = savesStore.editingSave {
                SaveEditorView(save: save)
            } else {
                SavesView()
            }
        } else if currentTab == "Profiles" {
            ModProfilesView()
        } else if currentTab == "Updates" {
            UpdatesView(currentTab: $currentTab)
        } else if currentTab == "ThaiHub" {
            ThaiTranslationHubView()
        } else if currentTab == "Settings" {
            SettingsView()
        } else if currentTab == "AppChangelog" {
            AppChangelogView()
        } else if currentTab == "Logs" {
            LogsView()
        } else {
            HomeView()
        }
    }

    private var navigationTitleText: String {
        if currentTab == "Saves" && savesStore.viewingSaveTimeline != nil { return localizationStore.L(L10n.Saves.timeline) }
        if currentTab == "Saves", let save = savesStore.editingSave { return save.playerName }
        if currentTab == "Mods", let config = modsStore.editingModConfig { return config.name }
        if currentTab == "Mods", let details = modsStore.viewingModDetails { return details.name }
        if currentTab == "ThaiHub", let thaiMod = thaiHubStore.viewingThaiMod { return thaiMod.name }
        if currentTab == "Mods" { return localizationStore.L(L10n.Mods.mods) }
        if currentTab == "ModPacks" { return localizationStore.L(L10n.ModPacks.title) }
        if currentTab == "Profiles" { return localizationStore.L(L10n.Profiles.title) }
        if currentTab == "Updates" { return localizationStore.L(L10n.Main.softwareUpdate) }
        if currentTab == "ThaiHub" { return localizationStore.L(L10n.ThaiHub.title) }
        if currentTab == "Saves" { return localizationStore.L(L10n.Saves.saves) }
        if currentTab == "Settings" { return localizationStore.L(L10n.Settings.settings) }
        if currentTab == "Logs" { return localizationStore.L(L10n.Logs.logs) }
        if currentTab == "AppChangelog" { return localizationStore.L(L10n.Main.appChangelog) }
        return localizationStore.L(L10n.Main.home)
    }
    
    var body: some View {
        NavigationSplitView {
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

        } detail: {
            // ── CONTENT AREA ─────────────────────────────────────────
            detailContent
            .onChange(of: currentTab, perform: { _ in
                savesStore.editingSave = nil
                modsStore.editingModConfig = nil
                modsStore.viewingModDetails = nil
                thaiHubStore.viewingThaiMod = nil
                
                if !isNavigatingBackOrForward {
                    if tabHistory.last != currentTab {
                        tabHistory.append(currentTab)
                        forwardHistory.removeAll()
                    }
                } else {
                    isNavigatingBackOrForward = false
                }
            })
            .background(Color(nsColor: .controlBackgroundColor))
            .toolbarBackground(.hidden, for: .automatic)
        }
        // End of NavigationSplitView
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Button(action: {
                        if savesStore.editingSave != nil {
                            savesStore.editingSave = nil
                        } else if modsStore.editingModConfig != nil {
                            modsStore.editingModConfig = nil
                        } else if modsStore.viewingModDetails != nil {
                            modsStore.viewingModDetails = nil
                        } else if thaiHubStore.viewingThaiMod != nil {
                            thaiHubStore.viewingThaiMod = nil
                        } else if tabHistory.count > 1 {
                            isNavigatingBackOrForward = true
                            let current = tabHistory.removeLast()
                            forwardHistory.append(current)
                            currentTab = tabHistory.last ?? "Home"
                        }
                    }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(savesStore.editingSave == nil && thaiHubStore.viewingThaiMod == nil && modsStore.editingModConfig == nil && modsStore.viewingModDetails == nil && tabHistory.count <= 1)
                    
                    Button(action: {
                        if let next = forwardHistory.popLast() {
                            isNavigatingBackOrForward = true
                            tabHistory.append(next)
                            currentTab = next
                        }
                    }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(forwardHistory.isEmpty)
                }
            }
            
            // Export Mod Pack button — shown only on the Mod Packs tab
            if currentTab == "ModPacks" {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let name = profilesStore.modProfiles.first { $0.id == profilesStore.activeProfileId }?.name ?? "My Pack"
                        if let _ = appCoordinator.exportModPack(name: name) {
                            alertStore.show( localizationStore.L(L10n.VM.modExported))
                        }
                    } label: {
                        Label(localizationStore.L(L10n.ModPacks.exportPack), systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .frame(minWidth: 820, minHeight: 520)
        .preferredColorScheme(colorScheme)
        .environment(\.locale, Locale(identifier: localizationStore.currentLanguage))
        .onReceive(NotificationCenter.default.publisher(for: .jumpToMod)) { notification in
            if let modName = notification.object as? String {
                modsStore.selectedModID = modsStore.mods
                    .flatMap { $0.allMods }
                    .first { $0.name.localizedCaseInsensitiveContains(modName) }?
                    .folderName
                currentTab = "Mods"
            }
        }
        .alert(isPresented: $alertStore.isPresented) {
            Alert(
                title: Text(localizationStore.L(L10n.Main.alert)),
                message: Text(alertStore.message),
                dismissButton: .default(Text(localizationStore.L(L10n.Main.ok)))
            )
        }
        .onReceive(URLDispatcher.shared.$openedURL) { url in
            if let u = url {
                appCoordinator.handleOpenURL(u)
                URLDispatcher.shared.openedURL = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { notification in
            if let tab = notification.object as? String {
                currentTab = tab
            }
        }
        // Available to every descendant view via @EnvironmentObject.
        .environmentObject(alertStore)
        .environmentObject(appCoordinator)
        .environmentObject(localizationStore)
        .environmentObject(logStore)
        .environmentObject(thaiHubStore)
        .environmentObject(profilesStore)
        .environmentObject(modPacksStore)
        .environmentObject(savesStore)
        .environmentObject(modsStore)
        .environmentObject(appEnvironment)
        .environmentObject(smapiInstaller)
    }
    
    var colorScheme: ColorScheme? {
        switch appColorScheme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Sidebar Section Header
struct SidebarSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 8)
            .padding(.top, 8)
            .padding(.bottom, 0)
    }
}

// MARK: - Sidebar Nav Item (macOS System Settings style)
struct SidebarNavItem: View {
    let icon: String
    let iconColor: Color
    let label: String
    let tab: String
    @Binding var currentTab: String
    @State private var isHovered = false

    var isSelected: Bool { currentTab == tab }

    var body: some View {
        Button(action: { currentTab = tab }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20, alignment: .center)
                
                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected
                          ? Color.accentColor
                          : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .pointingHandCursor()
    }
}

// MARK: - SMAPI Alerts UI
// MARK: - Updates View (macOS System Settings style)
struct UpdatesView: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @Binding var currentTab: String
    
    @State private var viewingModDetails: ModItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Out of date mods (Software Update style)
                if !modsStore.outOfDateMods.isEmpty {
                    ForEach(modsStore.outOfDateMods) { mod in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 16) {
                                // App Icon Fake
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                    Text(String(mod.name.prefix(2)).uppercased())
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.blue.opacity(0.8))
                                }
                                .frame(width: 56, height: 56)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mod.name)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(mod.version)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    
                    Text(localizationStore.L(L10n.Updates.newUpdate))
                                        .font(.system(size: 12))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.top, 2)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Button(action: {
                                        if let url = URL(string: mod.url) { NSWorkspace.shared.open(url) }
                                    }) {
                                        Text(localizationStore.L(L10n.Updates.download))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                            .background(Color.primary.opacity(0.1))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .pointingHandCursor()
                                    
                                    Button(action: {
                                        if let modItem = modsStore.mods.first(where: { $0.name == mod.name }) {
                                            viewingModDetails = modItem
                                        }
                                    }) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(localizationStore.L(L10n.Settings.nexusChangelog))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 16) {
                                Text(localizationStore.L(L10n.Updates.updateDescription))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                
                                Text("\(localizationStore.L(L10n.Updates.visitWebsite)) [\(mod.url)](\(mod.url))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .tint(.blue)
                                
                                Button(action: {
                                    if let modItem = modsStore.mods.first(where: { $0.name == mod.name }) {
                                        viewingModDetails = modItem
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                        Text(localizationStore.L(L10n.Settings.nexusChangelog))
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .pointingHandCursor()
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(12)
                    }
                }
                
                // SMAPI Errors (More Storage Required style)
                if !modsStore.smapiErrors.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 16))
                            let errorText = String(format: localizationStore.L(L10n.Updates.errorsFound), modsStore.smapiErrors.count)
                            Text(errorText)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: { currentTab = "Logs" }) {
                                Text(localizationStore.L(L10n.Updates.viewLogs))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.1))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                        }
                        
                        Text(localizationStore.L(L10n.Updates.errorDescription))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)
                        
                        ForEach(modsStore.smapiErrors, id: \.self) { error in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(12)
                }
                
            }
            .padding(20)
        }
        .sheet(item: $viewingModDetails) { modItem in
            ModDetailView(mod: modItem, initialTab: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

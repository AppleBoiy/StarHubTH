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
    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"

    init() {
        let container: DependencyContainer
        if let fixture = UITestFixture.current {
            container = DependencyContainer(filePicking: fixture.filePicking, preferenceStoring: fixture.preferenceStoring)
        } else {
            container = DependencyContainer()
        }
        let localizationStore = LocalizationStore()
        let logStore = LogStore()
        let appEnvironment = AppEnvironment(preferenceStoring: container.preferenceStoring, localization: localizationStore)
        let thaiHubStore = ThaiHubStore(localization: localizationStore)
        let profilesStore = ProfilesStore(profileStoring: container.profileStoring, localization: localizationStore)
        let modPacksStore = ModPacksStore(nexusAPIClient: container.nexusAPIClient, localization: localizationStore, logStore: logStore, filePicking: container.filePicking)
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
            MainSidebarView(currentTab: $currentTab, searchText: $searchText)
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
                Task { await appCoordinator.handleOpenURL(u) }
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

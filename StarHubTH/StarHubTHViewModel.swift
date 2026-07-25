import Foundation
import Cocoa
import SwiftUI
import Combine

final class StarHubTHViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    /// Phase 4.6: save-file state now lives in SavesStore
    /// (Features/Saves/SavesStore.swift). Assigned in init() since it depends on
    /// filePicking/localizationStore.
    let savesStore: SavesStore

    var saveViewMode: SaveViewMode {
        get { savesStore.saveViewMode }
        set { savesStore.saveViewMode = newValue }
    }
    var saveSortOption: SaveSortOption {
        get { savesStore.saveSortOption }
        set { savesStore.saveSortOption = newValue }
    }
    var saveFilterTag: String {
        get { savesStore.saveFilterTag }
        set { savesStore.saveFilterTag = newValue }
    }

    @Published var gameDir: String = "" {
        didSet {
            preferenceStoring.set(gameDir, forKey: "gameDir")
            self.refresh()
        }
    }
    
    @Published var showSmapiAlerts: Bool = false
    @Published var smapiInstalledVersion: String? = nil   // nil = not installed

    /// Phase 4.7: mod list, filters, custom tags, scanning, toggling, install, and
    /// Mods-directory backup/restore all live in ModsStore
    /// (Features/Mods/ModsStore.swift). Assigned in init() since it depends on
    /// filePicking/preferenceStoring/localizationStore.
    let modsStore: ModsStore

    var mods: [ModItem] {
        get { modsStore.mods }
        set { modsStore.mods = newValue }
    }
    var modFilterStatus: ModFilterStatus {
        get { modsStore.modFilterStatus }
        set { modsStore.modFilterStatus = newValue }
    }
    var modFilterTag: String {
        get { modsStore.modFilterTag }
        set { modsStore.modFilterTag = newValue }
    }
    var modFilterDate: ModFilterDate {
        get { modsStore.modFilterDate }
        set { modsStore.modFilterDate = newValue }
    }
    var modSortOption: ModSortOption {
        get { modsStore.modSortOption }
        set { modsStore.modSortOption = newValue }
    }
    var outOfDateMods: [ModUpdateInfo] {
        get { modsStore.outOfDateMods }
        set { modsStore.outOfDateMods = newValue }
    }
    var smapiErrors: [String] {
        get { modsStore.smapiErrors }
        set { modsStore.smapiErrors = newValue }
    }
    var isThaiTranslationInstalled: Bool {
        get { modsStore.isThaiTranslationInstalled }
        set { modsStore.isThaiTranslationInstalled = newValue }
    }
    var isSyncingAllTags: Bool {
        get { modsStore.isSyncingAllTags }
        set { modsStore.isSyncingAllTags = newValue }
    }
    var syncAllTagsProgress: Double {
        get { modsStore.syncAllTagsProgress }
        set { modsStore.syncAllTagsProgress = newValue }
    }
    var editingModConfig: ModItem? {
        get { modsStore.editingModConfig }
        set { modsStore.editingModConfig = newValue }
    }
    var viewingModDetails: ModItem? {
        get { modsStore.viewingModDetails }
        set { modsStore.viewingModDetails = newValue }
    }
    var downloadingMods: Set<String> {
        get { modsStore.downloadingMods }
        set { modsStore.downloadingMods = newValue }
    }
    var isInstallingMod: Bool {
        get { modsStore.isInstallingMod }
        set { modsStore.isInstallingMod = newValue }
    }
    var selectedMod: ModItem? {
        get { modsStore.selectedMod }
        set { modsStore.selectedMod = newValue }
    }
    var selectedModID: ModItem.FolderName? {
        get { modsStore.selectedModID }
        set { modsStore.selectedModID = newValue }
    }

    // Dependency Resolution Helper
    // Logic lives in ModGraph (Models/ModGraph.swift) so it is testable without a view model.
    func resolveDependencyStatus(for uniqueId: ModItem.UniqueID) -> DependencyStatus {
        modsStore.resolveDependencyStatus(for: uniqueId)
    }

    /// Resolves install status for a mod pack mod.
    /// Tries Nexus ID match first (via nexusUrl), then falls back to SMAPI uniqueId.
    func resolvePackModStatus(nexusId: ModItem.NexusID?, uniqueId: ModItem.UniqueID) -> PackModStatus {
        modsStore.resolvePackModStatus(nexusId: nexusId, uniqueId: uniqueId)
    }

    // Custom Tags
    var customModTags: [String: String] {
        get { modsStore.customModTags }
        set { modsStore.customModTags = newValue }
    }

    func setCustomTag(for modId: ModItem.UniqueID, tag: String, shouldRefresh: Bool = true) {
        modsStore.setCustomTag(for: modId, tag: tag, shouldRefresh: shouldRefresh, refresh: { [weak self] in self?.refresh() })
    }

    func resetCustomTag(for modId: ModItem.UniqueID) {
        modsStore.resetCustomTag(for: modId, refresh: { [weak self] in self?.refresh() })
    }

    func syncTagFromNexus(for mod: ModItem, shouldRefresh: Bool = true, completion: @escaping (Bool) -> Void) {
        modsStore.syncTagFromNexus(
            for: mod,
            nexusApiKey: nexusApiKey,
            shouldRefresh: shouldRefresh,
            refresh: { [weak self] in self?.refresh() },
            completion: completion
        )
    }

    func syncAllTagsFromNexus() {
        modsStore.syncAllTagsFromNexus(nexusApiKey: nexusApiKey, refresh: { [weak self] in self?.refresh() })
    }
    
    /// Phase 4.3: Thai Translation Hub state now lives in ThaiHubStore
    /// (Features/ThaiHub/ThaiHubStore.swift). Assigned in init() since it depends on
    /// localizationStore.
    let thaiHubStore: ThaiHubStore

    var thaiTranslations: [ThaiTranslationMod] {
        get { thaiHubStore.thaiTranslations }
        set { thaiHubStore.thaiTranslations = newValue }
    }
    var viewingThaiMod: ThaiTranslationMod? {
        get { thaiHubStore.viewingThaiMod }
        set { thaiHubStore.viewingThaiMod = newValue }
    }


    /// Phase 4.2: log state and SMAPI log tailing now live in LogStore
    /// (Features/Logs/LogStore.swift). Forwarded here so the 3 existing views that touch
    /// this state didn't need to change in this commit.
    let logStore = LogStore()

    var logOutput: String {
        get { logStore.logOutput }
        set { logStore.logOutput = newValue }
    }
    var logEntries: [LogEntry] {
        get { logStore.logEntries }
        set { logStore.logEntries = newValue }
    }
    var isReadingSMAPILog: Bool { logStore.isReadingSMAPILog }

    @Published var alertMessage: String = ""
    @Published var showAlert: Bool = false

    var saves: [SaveGameInfo] {
        get { savesStore.saves }
        set { savesStore.saves = newValue }
    }
    var editingSave: SaveGameInfo? {
        get { savesStore.editingSave }
        set { savesStore.editingSave = newValue }
    }
    var inventoryToEdit: [InventoryItem] {
        get { savesStore.inventoryToEdit }
        set { savesStore.inventoryToEdit = newValue }
    }
    var viewingSaveTimeline: SaveGameInfo? {
        get { savesStore.viewingSaveTimeline }
        set { savesStore.viewingSaveTimeline = newValue }
    }
    var saveToDuplicate: SaveGameInfo? {
        get { savesStore.saveToDuplicate }
        set { savesStore.saveToDuplicate = newValue }
    }
    var backupToBranch: SaveBackup? {
        get { savesStore.backupToBranch }
        set { savesStore.backupToBranch = newValue }
    }


    @Published var steamUsername: String = ""
    @Published var steamAvatarPath: String? = nil
    
    /// Phase 4.1: the actual localization logic and state now live in LocalizationStore
    /// (Localization/LocalizationStore.swift). This is a thin forwarding layer so the
    /// ~400 existing `vm.L(...)` / `vm.currentLanguage` call sites across every view
    /// didn't all need to change in the same commit as the extraction.
    let localizationStore = LocalizationStore()

    var currentLanguage: String {
        get { localizationStore.currentLanguage }
        set {
            objectWillChange.send()
            localizationStore.currentLanguage = newValue
        }
    }

    func makeDateFormatter(dateStyle: DateFormatter.Style = .short) -> DateFormatter {
        localizationStore.makeDateFormatter(dateStyle: dateStyle)
    }

    /// Phase 4.4: mod profile state now lives in ProfilesStore
    /// (Features/Profiles/ProfilesStore.swift). Assigned in init() since it depends on
    /// localizationStore.
    let profilesStore: ProfilesStore

    var modProfiles: [ModProfile] {
        get { profilesStore.modProfiles }
        set { profilesStore.modProfiles = newValue }
    }
    var activeProfileId: UUID? {
        get { profilesStore.activeProfileId }
        set { profilesStore.activeProfileId = newValue }
    }

    /// When true, toggling a mod also cascades to its dependencies / dependents.
    /// Persisted in UserDefaults so SettingsView @AppStorage stays in sync.
    var chainToggleDependencies: Bool {
        get { preferenceStoring.bool(forKey: "chainToggleDependencies") ?? true }
        set { preferenceStoring.set(newValue, forKey: "chainToggleDependencies") }
    }

    var nexusApiKey: String {
        get { preferenceStoring.string(forKey: "nexusApiKey") ?? "" }
    }

    let smapiInstaller = SmapiInstaller()
    private let filePicking: FilePicking = FilePicker()
    private let preferenceStoring: PreferenceStoring = PreferenceStore()

    init() {
        // Every stored property without a default must be assigned before any closure
        // captures `self` below — Swift's definite-initialization check treats a
        // self-capturing escaping closure as a potential read of ANY property, not just
        // the ones the closure actually touches.
        thaiHubStore = ThaiHubStore(localization: localizationStore)
        profilesStore = ProfilesStore(profileStoring: ProfileManager.shared, localization: localizationStore)
        modPacksStore = ModPacksStore(nexusAPIClient: LiveNexusAPIClient.shared, localization: localizationStore, logStore: logStore)
        savesStore = SavesStore(saveStoring: SaveManager.shared, saveNoteStoring: SaveNotesStore.shared, filePicking: filePicking, localization: localizationStore)
        modsStore = ModsStore(
            modScanning: ModScanner(),
            modInstalling: ModInstaller(),
            nexusAPIClient: LiveNexusAPIClient.shared,
            filePicking: filePicking,
            preferenceStoring: preferenceStoring,
            localization: localizationStore
        )

        // LogStore, ThaiHubStore, ProfilesStore, SavesStore, and ModsStore all mutate
        // their own @Published state from within their own methods (often via an async
        // dispatch), not just through a setter this ViewModel exposes — unlike
        // currentLanguage (Phase 4.1), a single objectWillChange.send() in a forwarding
        // setter isn't enough. Forward each store's own publisher instead. ModPacksStore
        // doesn't need this — its one @Published property only ever changes through the
        // ViewModel's own forwarding setter, which already calls objectWillChange.send()
        // manually.
        logStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        thaiHubStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        profilesStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        savesStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        modsStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Automatically retrieve saved game path, or attempt to find the default Steam path on Mac
        let savedPath = preferenceStoring.string(forKey: "gameDir") ?? ""
        if !savedPath.isEmpty && FileManager.default.fileExists(atPath: savedPath) {
            self.gameDir = savedPath
        } else {
            self.gameDir = self.detectDefaultGameDir()
        }
        self.refresh()
        self.loadProfiles()
        if self.steamUsername.isEmpty {
            self.steamUsername = L(L10n.VM.defaultFarmerName)
        }
        // Startup marker — confirms LogsView is receiving entries
        log("StarHubTH started", level: .info)
    }
    
    func detectDefaultGameDir() -> String {
        let home = NSHomeDirectory()
        let steamPath = "\(home)/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS"
        if FileManager.default.fileExists(atPath: steamPath) {
            return steamPath
        }
        
        let gogPath = "/Applications/Stardew Valley.app/Contents/MacOS"
        if FileManager.default.fileExists(atPath: gogPath) {
            return gogPath
        }
        
        return ""
    }
    @Published var requestedTab: String? = nil

    /// Phase 4.5: mod-pack export/import/collection-fetch now lives in ModPacksStore
    /// (Features/ModPacks/ModPacksStore.swift). Assigned in init() since it depends on
    /// localizationStore/logStore.
    let modPacksStore: ModPacksStore

    var importedModPack: StarHubPack? {
        get { modPacksStore.importedModPack }
        set {
            objectWillChange.send()
            modPacksStore.importedModPack = newValue
        }
    }

    func handleOpenURL(_ url: URL) {
        log("Opened with URL: \(url.absoluteString)", level: .info)
        
        guard url.scheme?.lowercased() == "nxm" else {
            self.log("Rejected: Not an NXM scheme")
            return
        }
        
        // Check if we have API key
        if self.nexusApiKey.isEmpty {
            showModal(message: L(L10n.VM.nexusPremiumRequired))
            return
        }
        
        if let result = NXMParser.parse(url: url) {
            switch result {
            case .mod(let modId, let fileId):
                log("Downloading from NXM: Mod \(modId), File \(fileId)", level: .info)
                self.downloadModFromNexus(nexusId: ModItem.NexusID(rawValue: modId), fileId: fileId) { success in
                    if success {
                        self.scanMods()
                        self.showModal(message: self.L(L10n.VM.nxmDownloadSuccess))
                    }
                }
            case .collection(let slug):
                log("Importing collection from NXM: \(slug)", level: .info)
                
                // Switch to the Mod Packs tab
                DispatchQueue.main.async {
                    self.requestedTab = "ModPacks"
                }
                // Trigger the import and save it to the view model
                self.importCollectionFromURL("https://next.nexusmods.com/stardewvalley/collections/\(slug)") { pack in
                    DispatchQueue.main.async {
                        if let p = pack {
                            self.importedModPack = p
                        } else {
                            // If it failed, importCollectionFromURL already showed a failure modal
                            self.log("Import collection returned nil.")
                        }
                    }
                }
            }
        } else {
            self.log("Unsupported or unrecognized NXM link format: \(url.absoluteString)")
        }
    }
    
    
    func selectGameDir() {
        if let url = filePicking.pickDirectory(title: nil) {
            self.gameDir = url.path
            preferenceStoring.set(self.gameDir, forKey: "gameDir")
            scanMods()
            checkSmapiVersion()
        }
    }
    
    func localizedString(for key: String) -> String {
        localizationStore.localizedString(for: key)
    }

    /// Typed-key shorthand. Prefer this over localizedString(for:) with raw strings.
    /// Example: vm.L(L10n.Mods.enabled)
    func L(_ key: String) -> String {
        localizationStore.L(key)
    }

    func localizedTag(_ tag: String) -> String {
        localizationStore.localizedTag(tag)
    }

    func refresh() {
        self.checkSmapiVersion()
        self.scanMods()
        self.reloadSaves()
        self.fetchSteamUser()
    }
    
    func fetchSteamUser() {
        let home = NSHomeDirectory()
        let vdfPath = "\(home)/Library/Application Support/Steam/config/loginusers.vdf"
        guard let content = try? String(contentsOfFile: vdfPath, encoding: .utf8) else { return }
        
        // Very basic VDF parsing
        var currentSteamID = ""
        var personaName = ""
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let tLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if tLine.hasPrefix("\"7656") {
                currentSteamID = tLine.replacingOccurrences(of: "\"", with: "")
            }
            if tLine.hasPrefix("\"PersonaName\"") {
                let parts = tLine.components(separatedBy: "\"")
                if parts.count >= 4 { personaName = parts[3] }
            }
            if tLine.hasPrefix("\"MostRecent\"") && tLine.contains("\"1\"") {
                break
            }
        }
        
        if !personaName.isEmpty {
            self.steamUsername = personaName
        } else {
            let defaultName = NSFullUserName().components(separatedBy: " ").first ?? ""
            self.steamUsername = defaultName.isEmpty ? L(L10n.VM.defaultFarmerName) : defaultName
        }
        
        if !currentSteamID.isEmpty {
            let avatarPathPng = "\(home)/Library/Application Support/Steam/config/avatarcache/\(currentSteamID).png"
            let avatarPathJpg = "\(home)/Library/Application Support/Steam/config/avatarcache/\(currentSteamID).jpg"
            if FileManager.default.fileExists(atPath: avatarPathPng) {
                self.steamAvatarPath = avatarPathPng
            } else if FileManager.default.fileExists(atPath: avatarPathJpg) {
                self.steamAvatarPath = avatarPathJpg
            }
        }
    }
    
    func checkSmapiVersion() {
        guard !gameDir.isEmpty else {
            self.smapiInstalledVersion = nil
            return
        }
        self.smapiInstalledVersion = SmapiInstaller.getInstalledVersion(gameDir: gameDir)
    }
    
    func scanMods() {
        modsStore.scanMods(gameDir: gameDir)
    }

    // Parses the SMAPI-latest.txt log for updates and errors
    func parseSMAPILog() {
        modsStore.parseSMAPILog(gameDir: gameDir)
    }

    // Returns missing required unique IDs for a given mod
    func getMissingDependencies(for mod: ModItem) -> [ModItem.UniqueID] {
        modsStore.getMissingDependencies(for: mod)
    }

    // Toggle Mod Status (Enabled / Disabled)
    func toggleMod(_ mod: ModItem) {
        modsStore.toggleMod(
            mod,
            gameDir: gameDir,
            chainToggleDependencies: chainToggleDependencies,
            log: { [weak self] message in self?.log(message) },
            onToggled: { [weak self] in self?.syncActiveProfileIds() }
        )
    }

    // MARK: - Install Mod (ZIP or Folder)

    /// Opens a file picker — accepts both .zip files AND already-extracted folders.
    func openInstallModPanel() {
        modsStore.openInstallModPanel(
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            log: { [weak self] message in self?.log(message) }
        )
    }

    /// Entry point — detects whether the URL is a .zip or a folder and routes accordingly.
    func installMod(url: URL) {
        modsStore.installMod(
            url: url,
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            log: { [weak self] message in self?.log(message) }
        )
    }

    /// Installs a mod from a .zip file
    func installModFromZip(url: URL, completion: ((Bool) -> Void)? = nil) {
        modsStore.installModFromZip(
            url: url,
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            log: { [weak self] message in self?.log(message) },
            completion: completion
        )
    }

    /// Installs a mod from an already-extracted folder.
    func installModFromFolder(url: URL) {
        modsStore.installModFromFolder(
            url: url,
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            log: { [weak self] message in self?.log(message) }
        )
    }

    // MARK: - Nexus Auto-Download
    
    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: ModItem.NexusID) {
        modsStore.downloadAndInstallUpdate(
            for: mod,
            nexusId: nexusId,
            nexusApiKey: nexusApiKey,
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            log: { [weak self] message in self?.log(message) }
        )
    }

    // Install SMAPI via Installer Helper
    func installSmapi() {
        smapiInstaller.install(gameDir: gameDir) { success, msgKey, detail in
            self.checkSmapiVersion()
            let message = detail != nil ? "\(self.L(msgKey))\n\(detail!)" : self.L(msgKey)
            self.showModal(message: message)
            self.log(message)
        }
    }
    
    // Uninstall SMAPI
    func uninstallSmapi() {
        smapiInstaller.uninstall(gameDir: gameDir) { success, msgKey, detail in
            self.checkSmapiVersion()
            let message = detail != nil ? "\(self.L(msgKey))\n\(detail!)" : self.L(msgKey)
            self.showModal(message: message)
            self.log(message)
        }
    }
    
    func log(_ message: String, level: LogLevel = .info) {
        logStore.log(message, level: level)
    }

    /// Load SMAPI-latest.txt asynchronously when Logs tab is opened.
    func loadSmapiLog() {
        logStore.loadSmapiLog()
    }

    func startSmapiLogWatcher() { logStore.startSmapiLogWatcher() }
    func stopSmapiLogWatcher() { logStore.stopSmapiLogWatcher() }

    func showModal(message: String) {
        self.alertMessage = message
        self.showAlert = true
    }
    
    // MARK: - Saves
    func reloadSaves() {
        savesStore.reloadSaves()
    }

    func editSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) {
        savesStore.editSave(
            info: info, newName: newName, newFarm: newFarm, newFav: newFav, newMoney: newMoney,
            newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newMaxHealth, newMaxStamina: newMaxStamina,
            newGoldenWalnuts: newGoldenWalnuts, newQiGems: newQiGems, newClubCoins: newClubCoins, newSpouse: newSpouse,
            showModal: { [weak self] message in self?.showModal(message: message) }
        )
    }

    func saveInventory() {
        savesStore.saveInventory(showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func deleteSave(info: SaveGameInfo) {
        savesStore.deleteSave(info: info, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    var savesHierarchy: [SaveNode] {
        savesStore.savesHierarchy
    }

    var availableFilterTags: [String] {
        savesStore.availableFilterTags
    }

    func setAvatar(forSave folderName: String, iconPath: String) {
        savesStore.setAvatar(forSave: folderName, iconPath: iconPath)
    }

    func selectCustomAvatar(forSave folderName: String, completion: ((String) -> Void)? = nil) {
        savesStore.selectCustomAvatar(forSave: folderName, completion: completion)
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) {
        savesStore.duplicateSave(info: info, newName: newName, newFarm: newFarm, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func openSaveInFinder(info: SaveGameInfo) {
        savesStore.openSaveInFinder(info: info)
    }

    // MARK: - Backup Timeline

    func listBackups(for info: SaveGameInfo) -> [SaveBackup] {
        savesStore.listBackups(for: info)
    }

    func createBackup(info: SaveGameInfo) -> Bool {
        savesStore.createBackup(info: info)
    }

    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) -> Bool {
        savesStore.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) {
        savesStore.restoreBackup(backup: backup, info: info, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func deleteBackup(_ backup: SaveBackup) -> Bool {
        savesStore.deleteBackup(backup)
    }

    // MARK: - Save Notes

    func getNote(for folderName: String) -> SaveNote {
        savesStore.getNote(for: folderName)
    }

    func setNote(for folderName: String, tag: String, note: String) {
        savesStore.setNote(for: folderName, tag: tag, note: note)
    }

    // MARK: - Backup & Management
    func backupAllSaves() {
        savesStore.backupAllSaves(showModal: { [weak self] message in self?.showModal(message: message) })
    }
    
    func backupAllMods() {
        modsStore.backupAllMods(gameDir: gameDir, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func backupMod(mod: ModItem) {
        modsStore.backupMod(mod: mod, gameDir: gameDir, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func restoreModZip(mod: ModItem) {
        modsStore.restoreModZip(mod: mod, gameDir: gameDir, showModal: { [weak self] message in self?.showModal(message: message) })
    }

    func cleanDisabledMods() {
        modsStore.cleanDisabledMods(gameDir: gameDir, showModal: { [weak self] message in self?.showModal(message: message) })
    }
    
    // MARK: - Thai Translation Hub Logic
    
    func fetchThaiTranslations() {
        thaiHubStore.fetchThaiTranslations(gameDir: gameDir, mods: mods)
    }

    func evaluateThaiTranslationStatus() {
        thaiHubStore.evaluateThaiTranslationStatus(gameDir: gameDir, mods: mods)
    }

    func installThaiTranslation(mod: ThaiTranslationMod) {
        thaiHubStore.installThaiTranslation(
            mod: mod,
            gameDir: gameDir,
            showModal: { [weak self] message in self?.showModal(message: message) },
            onInstalled: { [weak self] in self?.evaluateThaiTranslationStatus() }
        )
    }
    
    func openSavesFolder() {
        savesStore.openSavesFolder()
    }
    
    // MARK: - Mod Profiles
    func loadProfiles() {
        profilesStore.loadProfiles()
    }

    func saveProfiles() {
        profilesStore.saveProfiles()
    }

    func createProfile(name: String) {
        profilesStore.createProfile(name: name, mods: mods)
    }

    func deleteProfile(id: UUID) {
        profilesStore.deleteProfile(id: id)
    }

    func updateProfile(id: UUID, newName: String, enabledModIds: [ModItem.UniqueID]) {
        profilesStore.updateProfile(
            id: id,
            newName: newName,
            enabledModIds: enabledModIds,
            gameDir: gameDir,
            modsProvider: { [weak self] in self?.mods ?? [] },
            scanMods: { [weak self] in self?.scanMods() }
        )
    }

    func applyProfile(id: UUID?) {
        profilesStore.applyProfile(
            id: id,
            gameDir: gameDir,
            modsProvider: { [weak self] in self?.mods ?? [] },
            scanMods: { [weak self] in self?.scanMods() },
            log: { [weak self] message in self?.log(message) },
            showModal: { [weak self] message in self?.showModal(message: message) }
        )
    }

    /// Compute which uniqueIds should be added/removed when toggling a mod in a profile,
    /// using the same chain logic as toggleMod. Works on an in-memory set (no file I/O).
    /// - Parameters:
    ///   - mod: The mod being toggled (can be a group or single mod)
    ///   - enable: true = enabling, false = disabling
    ///   - currentEnabled: the current set of enabled uniqueIds in the profile
    /// - Returns: A new set with the chain applied
    func applyChainToSet(mod: ModItem, enable: Bool, currentEnabled: Set<ModItem.UniqueID>) -> Set<ModItem.UniqueID> {
        profilesStore.applyChainToSet(mod: mod, enable: enable, currentEnabled: currentEnabled, mods: mods, chainToggleDependencies: chainToggleDependencies)
    }

    /// Call this after any toggleMod so the profile stays up to date.
    func syncActiveProfileIds() {
        profilesStore.syncActiveProfileIds(mods: mods)
    }


    // MARK: - Mod Pack Sharing

    func exportModPack(name: String) -> URL? {
        modPacksStore.exportModPack(
            name: name,
            mods: mods,
            steamUsername: steamUsername,
            showModal: { [weak self] message in self?.showModal(message: message) }
        )
    }

    func importModPack(from url: URL) -> StarHubPack? {
        modPacksStore.importModPack(from: url)
    }

    func importCollectionFromURL(_ urlString: String, completion: @escaping (StarHubPack?) -> Void) {
        modPacksStore.importCollectionFromURL(
            urlString,
            nexusApiKey: nexusApiKey,
            showModal: { [weak self] message in self?.showModal(message: message) },
            completion: completion
        )
    }

    func downloadModFromNexus(nexusId: ModItem.NexusID, fileId: Int? = nil, completion: @escaping (Bool) -> Void) {
        modPacksStore.downloadModFromNexus(
            nexusId: nexusId,
            fileId: fileId,
            nexusApiKey: nexusApiKey,
            installModFromZip: { [weak self] url, completion in self?.installModFromZip(url: url, completion: completion) },
            completion: completion
        )
    }
}

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
    
    @Published var outOfDateMods: [ModUpdateInfo] = []
    @Published var smapiErrors: [String] = []
    @Published var showSmapiAlerts: Bool = false
    
    @Published var smapiInstalledVersion: String? = nil   // nil = not installed
    @Published var mods: [ModItem] = []
    
    // Current filter options
    @Published var modFilterStatus: ModFilterStatus = .all
    @Published var modFilterTag: String = ""
    @Published var modFilterDate: ModFilterDate = .all
    @Published var modSortOption: ModSortOption = .name
    
    // Dependency Resolution Helper
    // Logic lives in ModGraph (Models/ModGraph.swift) so it is testable without a view model.
    func resolveDependencyStatus(for uniqueId: ModItem.UniqueID) -> DependencyStatus {
        ModGraph.dependencyStatus(for: uniqueId, in: mods)
    }

    /// Resolves install status for a mod pack mod.
    /// Tries Nexus ID match first (via nexusUrl), then falls back to SMAPI uniqueId.
    func resolvePackModStatus(nexusId: ModItem.NexusID?, uniqueId: ModItem.UniqueID) -> PackModStatus {
        ModGraph.packModStatus(nexusID: nexusId, uniqueId: uniqueId, in: mods)
    }

    // Custom Tags
    var customModTags: [String: String] {
        get { preferenceStoring.dictionary(forKey: "customModTags") ?? [:] }
        set { preferenceStoring.set(newValue, forKey: "customModTags") }
    }

    func setCustomTag(for modId: ModItem.UniqueID, tag: String, shouldRefresh: Bool = true) {
        var tags = customModTags
        tags[modId.rawValue] = tag
        customModTags = tags
        if shouldRefresh { refresh() }
    }

    func resetCustomTag(for modId: ModItem.UniqueID) {
        var tags = customModTags
        tags.removeValue(forKey: modId.rawValue)
        customModTags = tags
        refresh()
    }
    
    func syncTagFromNexus(for mod: ModItem, shouldRefresh: Bool = true, completion: @escaping (Bool) -> Void) {
        let apiKey = nexusApiKey
        guard !apiKey.isEmpty, let url = URL(string: mod.nexusUrl), let modId = Int(url.lastPathComponent) else {
            completion(false)
            return
        }
        
        LiveNexusAPIClient.shared.getModInfo(modId: modId, apiKey: apiKey) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    if let categoryId = info.categoryId {
                        let newTag = LiveNexusAPIClient.categoryTag(from: categoryId)
                        self?.setCustomTag(for: mod.uniqueId, tag: newTag, shouldRefresh: shouldRefresh)
                        completion(true)
                    } else {
                        completion(false)
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
    
    @Published var isSyncingAllTags = false
    @Published var syncAllTagsProgress: Double = 0.0
    
    func syncAllTagsFromNexus() {
        let apiKey = nexusApiKey
        guard !apiKey.isEmpty else { return }
        
        isSyncingAllTags = true
        syncAllTagsProgress = 0.0
        
        let modsToSync = mods.filter { !$0.nexusUrl.isEmpty && Int((URL(string: $0.nexusUrl)?.lastPathComponent) ?? "") != nil }
        var completedCount = 0
        
        guard !modsToSync.isEmpty else {
            isSyncingAllTags = false
            return
        }
        
        for mod in modsToSync {
            syncTagFromNexus(for: mod, shouldRefresh: false) { _ in
                DispatchQueue.main.async {
                    completedCount += 1
                    self.syncAllTagsProgress = Double(completedCount) / Double(modsToSync.count)
                    if completedCount >= modsToSync.count {
                        self.isSyncingAllTags = false
                        self.refresh()
                    }
                }
            }
        }
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
    @Published var isThaiTranslationInstalled: Bool = false
    
    @Published var editingModConfig: ModItem? = nil
    @Published var viewingModDetails: ModItem? = nil

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
    
    @Published var downloadingMods: Set<String> = []
    
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

        // LogStore, ThaiHubStore, ProfilesStore, and SavesStore all mutate their own
        // @Published state from within their own methods (often via an async dispatch),
        // not just through a setter this ViewModel exposes — unlike currentLanguage
        // (Phase 4.1), a single objectWillChange.send() in a forwarding setter isn't
        // enough. Forward each store's own publisher instead. ModPacksStore doesn't need
        // this — its one @Published property only ever changes through the ViewModel's
        // own forwarding setter, which already calls objectWillChange.send() manually.
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
        let scannedMods = ModScanner.scan(gameDir: gameDir, customModTags: customModTags)
        
        parseSMAPILog()
            
        DispatchQueue.main.async {
            self.mods = scannedMods
            if self.selectedMod == nil, let first = self.mods.first {
                self.selectedMod = first
            }
            self.isThaiTranslationInstalled = scannedMods.contains {
                ($0.folderName.rawValue.lowercased() == "stardew valley - thai" ||
                $0.name.localizedCaseInsensitiveContains("thai")) && $0.isEnabled
            }
        }
    }
    
    // Parses the SMAPI-latest.txt log for updates and errors
    func parseSMAPILog() {
        guard !gameDir.isEmpty else { return }
        
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let logPath = (homeDir as NSString).appendingPathComponent(".config/StardewValley/ErrorLogs/SMAPI-latest.txt")
        guard FileManager.default.fileExists(atPath: logPath),
              let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            DispatchQueue.main.async {
                self.outOfDateMods = []
                self.smapiErrors = []
            }
            return
        }
        
        let result = SmapiLogParser.parse(logContent: logContent)
        
        DispatchQueue.main.async {
            self.outOfDateMods = result.outOfDateMods
            self.smapiErrors = result.errors
        }
    }
    
    // Returns missing required unique IDs for a given mod
    func getMissingDependencies(for mod: ModItem) -> [ModItem.UniqueID] {
        ModGraph.missingDependencies(for: mod, in: mods)
    }

    // Toggle Mod Status (Enabled / Disabled)
    func toggleMod(_ mod: ModItem) {
        // Helper to find the top-level folder that contains a given uniqueId
        func getTopLevelFolder(for uniqueId: ModItem.UniqueID) -> ModItem.FolderName? {
            for m in self.mods {
                switch m.kind {
                case .single:
                    if m.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame {
                        return m.folderName
                    }
                case .group(let children):
                    if children.contains(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(uniqueId.rawValue) == .orderedSame }) {
                        return m.folderName
                    }
                }
            }
            return nil
        }

        // Helper to get all dependencies of a top-level folder (including its children)
        func getDependencies(for folderName: ModItem.FolderName) -> [ModDependency] {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { return [] }
            if case .group(let children) = m.kind {
                return children.flatMap { $0.dependencies }
            } else {
                return m.dependencies
            }
        }

        var foldersToToggle: Set<ModItem.FolderName> = [mod.folderName]
        let targetState = !mod.isEnabled // True if we are enabling, false if disabling

        if chainToggleDependencies {
            if targetState == true {
                // Enabling: recursively enable all REQUIRED dependencies
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()
                    let deps = getDependencies(for: currentFolder)

                    for dep in deps where dep.isRequired {
                        if let depFolder = getTopLevelFolder(for: dep.uniqueId) {
                            let isDepFolderEnabled = self.mods.first(where: { $0.folderName == depFolder })?.isEnabled ?? false
                            if !isDepFolderEnabled && !foldersToToggle.contains(depFolder) {
                                foldersToToggle.insert(depFolder)
                                queue.append(depFolder)
                            }
                        }
                    }
                }
            } else {
                // Disabling: recursively disable all enabled mods that REQUIRE this mod
                var queue = [mod.folderName]
                while !queue.isEmpty {
                    let currentFolder = queue.removeFirst()

                    var providedUniqueIds: [ModItem.UniqueID] = []
                    if let m = self.mods.first(where: { $0.folderName == currentFolder }) {
                        if case .group(let children) = m.kind {
                            providedUniqueIds = children.map { $0.uniqueId }
                        } else {
                            providedUniqueIds = [m.uniqueId]
                        }
                    }

                    for otherMod in self.mods where otherMod.isEnabled && !foldersToToggle.contains(otherMod.folderName) {
                        let otherDeps = getDependencies(for: otherMod.folderName)
                        let requiresCurrent = otherDeps.contains { dep in
                            dep.isRequired && providedUniqueIds.contains { $0.rawValue.caseInsensitiveCompare(dep.uniqueId.rawValue) == .orderedSame }
                        }
                        if requiresCurrent {
                            foldersToToggle.insert(otherMod.folderName)
                            queue.append(otherMod.folderName)
                        }
                    }
                }
            }
        }
        // else: chainToggleDependencies == false → only toggle the single mod itself

        let fm = FileManager.default
        let modsPath = (gameDir as NSString).appendingPathComponent("Mods")
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        var anyMoved = false

        for folderName in foldersToToggle {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { continue }
            if m.isEnabled == targetState { continue }

            let srcPath = ((m.isEnabled ? modsPath : disabledModsPath) as NSString).appendingPathComponent(m.folderName.rawValue)
            let destFolder = m.isEnabled ? disabledModsPath : modsPath
            let destPath = ((destFolder as NSString).appendingPathComponent(m.folderName.rawValue) as String)
            
            let destBackup = "\(destPath)_toggle_backup_temp"
            do {
                let destParent = (destPath as NSString).deletingLastPathComponent
                if !fm.fileExists(atPath: destParent) {
                    try fm.createDirectory(atPath: destParent, withIntermediateDirectories: true, attributes: nil)
                }
                if fm.fileExists(atPath: destPath) {
                    if fm.fileExists(atPath: destBackup) {
                        try? fm.removeItem(atPath: destBackup)
                    }
                    try fm.moveItem(atPath: destPath, toPath: destBackup)
                }
                
                do {
                    try fm.moveItem(atPath: srcPath, toPath: destPath)
                    if fm.fileExists(atPath: destBackup) {
                        try? fm.trashItem(at: URL(fileURLWithPath: destBackup), resultingItemURL: nil)
                    }
                    anyMoved = true
                } catch {
                    if fm.fileExists(atPath: destBackup) && !fm.fileExists(atPath: destPath) {
                        try? fm.moveItem(atPath: destBackup, toPath: destPath)
                    }
                    throw error
                }
            } catch {
                print("Failed to toggle \(m.name): \(error.localizedDescription)")
            }
        }
        
        if anyMoved {
            log("\(targetState ? L(L10n.Mods.enabled) : L(L10n.Mods.disabled)): \(mod.name)\(foldersToToggle.count > 1 ? " + Dependencies" : "")")
            self.scanMods()
            self.syncActiveProfileIds()
        }
    }
    
    // MARK: - Install Mod (ZIP or Folder)

    @Published var isInstallingMod: Bool = false

    /// Opens a file picker — accepts both .zip files AND already-extracted folders.
    func openInstallModPanel() {
        let urls = filePicking.pickFiles(
            title: L(L10n.Mods.installMod),
            allowedContentTypes: [.init(filenameExtension: "zip")!],
            allowsMultipleSelection: true,
            canChooseDirectories: true   // ← also accept extracted folders
        )
        for url in urls {
            installMod(url: url)
        }
    }

    /// Entry point — detects whether the URL is a .zip or a folder and routes accordingly.
    func installMod(url: URL) {
        guard !gameDir.isEmpty else {
            showModal(message: L(L10n.Settings.gameDirNotSet))
            return
        }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            installModFromFolder(url: url)
        } else if url.pathExtension.lowercased() == "zip" {
            installModFromZip(url: url)
        } else {
            showModal(message: L(L10n.Mods.installInvalidFile))
        }
    }

    /// Installs a mod from a .zip file
    func installModFromZip(url: URL, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async { self.isInstallingMod = true }
        ModInstaller.installFromZip(url: url, gameDir: gameDir) { [weak self] result in
            guard let self = self else { completion?(false); return }
            self.handleInstallResult(result, completion: completion)
        }
    }

    /// Installs a mod from an already-extracted folder.
    func installModFromFolder(url: URL) {
        DispatchQueue.main.async { self.isInstallingMod = true }
        ModInstaller.installFromFolder(url: url, gameDir: gameDir) { [weak self] result in
            guard let self = self else { return }
            self.handleInstallResult(result)
        }
    }
    
    private func handleInstallResult(_ result: Result<[String], ModInstallerError>, completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.main.async {
            self.isInstallingMod = false
            switch result {
            case .success(let installedNames):
                let names = installedNames.joined(separator: ", ")
                let msg = String(format: self.L(L10n.Mods.installSuccess), names)
                self.showModal(message: msg)
                self.log(msg)
                self.scanMods()
                completion?(true)
            case .failure(let error):
                switch error {
                case .noModFound:
                    self.log("Install failed: No manifest.json found in extracted content (gameDir: \(self.gameDir))")
                    self.showModal(message: self.L(L10n.Mods.installNoModFound))
                case .unzipProcessError:
                    self.log("Install failed: unzip process error")
                    self.showModal(message: self.L(L10n.VM.unzipError))
                case .unzipFailed(let msg), .other(let msg):
                    self.log("Install failed: \(msg)")
                    self.showModal(message: String(format: self.L(L10n.VM.unzipFailed), msg))
                }
                completion?(false)
            }
        }
    }

    // MARK: - Nexus Auto-Download
    
    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: ModItem.NexusID) {
        DispatchQueue.main.async {
            self.downloadingMods.insert(mod.name)
        }
        
        NexusDownloader.downloadUpdate(nexusId: nexusId, apiKey: self.nexusApiKey) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let zipUrl):
                DispatchQueue.main.async {
                    self.downloadingMods.remove(mod.name)
                    self.installModFromZip(url: zipUrl)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.downloadingMods.remove(mod.name)
                    self.showModal(message: error.localizedDescription)
                }
            }
        }
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
    
    @Published var selectedMod: ModItem? = nil {
        didSet {
            if let mod = selectedMod, selectedModID != mod.folderName {
                selectedModID = mod.folderName
            }
        }
    }
    @Published var selectedModID: ModItem.FolderName? = nil {
        didSet {
            if let id = selectedModID, selectedMod?.folderName != id {
                selectedMod = mods.first { $0.folderName == id }
            }
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
        guard !gameDir.isEmpty else {
            showModal(message: L(L10n.Settings.gameDirNotSet))
            return
        }
        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")
        let home = NSHomeDirectory()
        let desktopDir = "\(home)/Desktop"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let zipPath = "\(desktopDir)/StardewMods_Backup_\(timestamp).zip"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: modsDir)
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                showModal(message: String(format: L(L10n.VM.backupModsSuccess), zipPath))
            } else {
                showModal(message: L(L10n.VM.zipModsError))
            }
        } catch {
            showModal(message: L(L10n.VM.cannotRunZip))
        }
    }
    
    func backupMod(mod: ModItem) {
        guard !gameDir.isEmpty else {
            showModal(message: L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let defaultFileName = "\(mod.folderName.rawValue)_Backup_\(timestamp).zip"
        
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.title = "Save Backup"
            panel.nameFieldStringValue = defaultFileName
            panel.allowedContentTypes = [.zip]
            panel.canCreateDirectories = true
            
            if panel.runModal() == .OK, let url = panel.url {
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    process.arguments = ["-r", url.path, "."]
                    process.currentDirectoryURL = URL(fileURLWithPath: modDir)
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        DispatchQueue.main.async {
                            if process.terminationStatus == 0 {
                                self.showModal(message: String(format: self.L(L10n.VM.backupModsSuccess), url.path))
                            } else {
                                self.showModal(message: self.L(L10n.VM.zipModsError))
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.showModal(message: self.L(L10n.VM.cannotRunZip))
                        }
                    }
                }
            }
        }
    }
    
    func restoreModZip(mod: ModItem) {
        guard !gameDir.isEmpty else {
            showModal(message: L(L10n.Settings.gameDirNotSet))
            return
        }
        let basePath = (gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)

        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.title = "Select Mod Backup (.zip)"
            panel.allowedContentTypes = [.init(filenameExtension: "zip")!]
            panel.allowsMultipleSelection = false
            
            if panel.runModal() == .OK, let zipUrl = panel.url {
                DispatchQueue.global(qos: .userInitiated).async {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                    process.arguments = ["-o", zipUrl.path, "-d", modDir]
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        DispatchQueue.main.async {
                            if process.terminationStatus == 0 {
                                self.showModal(message: self.L(L10n.VM.modZipRestoreSuccess))
                                self.scanMods()
                            } else {
                                self.showModal(message: self.L(L10n.VM.modZipRestoreFailed))
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.showModal(message: self.L(L10n.VM.modZipRestoreError))
                        }
                    }
                }
            }
        }
    }
    
    func cleanDisabledMods() {
        guard !gameDir.isEmpty else { return }
        let disabledModsPath = (gameDir as NSString).appendingPathComponent("Mods_disabled")
        do {
            if FileManager.default.fileExists(atPath: disabledModsPath) {
                try FileManager.default.removeItem(atPath: disabledModsPath)
                showModal(message: L(L10n.VM.cleanModsSuccess))
                self.scanMods()
            } else {
                showModal(message: L(L10n.VM.cleanModsNotFound))
            }
        } catch {
            showModal(message: String(format: L(L10n.VM.cleanModsError), error.localizedDescription))
        }
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

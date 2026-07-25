import Foundation
import Cocoa
import SwiftUI
import Combine

final class StarHubTHViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    @Published var saveViewMode: SaveViewMode = .list
    @Published var saveSortOption: SaveSortOption = .lastPlayed
    @Published var saveFilterTag: String = ""

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
    
    @Published var saves: [SaveGameInfo] = []
    @Published var editingModConfig: ModItem? = nil
    @Published var viewingModDetails: ModItem? = nil
    @Published var editingSave: SaveGameInfo? = nil {
        didSet {
            if let save = editingSave {
                if let items = SaveManager.shared.fetchInventory(for: save) {
                    inventoryToEdit = items
                } else {
                    inventoryToEdit = []
                }
            } else {
                inventoryToEdit = []
            }
        }
    }
    @Published var inventoryToEdit: [InventoryItem] = []
    @Published var viewingSaveTimeline: SaveGameInfo? = nil
    
    @Published var saveToDuplicate: SaveGameInfo? = nil
    @Published var backupToBranch: SaveBackup? = nil
    
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

    @Published var modProfiles: [ModProfile] = []
    @Published var activeProfileId: UUID? = nil

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

        // LogStore and ThaiHubStore both mutate their own @Published state from within
        // their own methods (often via an async dispatch), not just through a setter
        // this ViewModel exposes — unlike currentLanguage (Phase 4.1), a single
        // objectWillChange.send() in a forwarding setter isn't enough. Forward each
        // store's own publisher instead.
        logStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        thaiHubStore.objectWillChange
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
    @Published var importedModPack: StarHubPack? = nil

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
        self.saves = SaveManager.shared.fetchSaves()
    }
    
    func editSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) {
        let success = SaveManager.shared.updateSave(info: info, newName: newName, newFarm: newFarm, newFav: newFav, newMoney: newMoney, newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newMaxHealth, newMaxStamina: newMaxStamina, newGoldenWalnuts: newGoldenWalnuts, newQiGems: newQiGems, newClubCoins: newClubCoins, newSpouse: newSpouse)
        if success {
            reloadSaves()
            showModal(message: L(L10n.VM.saveSuccess))
        } else {
            showModal(message: L(L10n.VM.saveError))
        }
    }
    
    func saveInventory() {
        guard let save = editingSave else { return }
        if SaveManager.shared.updateInventory(info: save, items: inventoryToEdit) {
            showModal(message: L(L10n.Saves.inventorySuccess))
            if let items = SaveManager.shared.fetchInventory(for: save) {
                inventoryToEdit = items
            }
        } else {
            showModal(message: L(L10n.Saves.inventoryError))
        }
    }
    func deleteSave(info: SaveGameInfo) {
        if SaveManager.shared.deleteSave(info: info) {
            reloadSaves()
            showModal(message: L(L10n.VM.deleteSaveSuccess))
        } else {
            showModal(message: L(L10n.VM.deleteSaveError))
        }
    }
    
    var savesHierarchy: [SaveNode] {
        let saveNames = Set(saves.map(\.folderName))
        
        func getParentFolderName(for folderName: String) -> String? {
            var candidate = folderName
            while let range = candidate.range(of: "_", options: .backwards) {
                candidate = String(candidate[..<range.lowerBound])
                if saveNames.contains(candidate) {
                    return candidate
                }
            }
            return nil
        }
        
        func sortedNodes(_ nodes: [SaveNode]) -> [SaveNode] {
            nodes
                .map { SaveNode(info: $0.info, children: sortedNodes($0.children)) }
                .sorted { a, b in
                    switch saveSortOption {
                    case .name:
                        return a.info.playerName.localizedCaseInsensitiveCompare(b.info.playerName) == .orderedAscending
                    case .lastPlayed:
                        return a.info.lastModified > b.info.lastModified
                    case .money:
                        return a.info.money > b.info.money
                    }
                }
        }
        
        var childrenByParent: [String: [SaveGameInfo]] = [:]
        var rootSaves: [SaveGameInfo] = []
        
        for save in saves {
            if let parentFolderName = getParentFolderName(for: save.folderName) {
                childrenByParent[parentFolderName, default: []].append(save)
            } else {
                rootSaves.append(save)
            }
        }
        
        func buildNode(for save: SaveGameInfo) -> SaveNode {
            let children = childrenByParent[save.folderName, default: []].map { buildNode(for: $0) }
            return SaveNode(info: save, children: children)
        }
        
        var roots = rootSaves.map { buildNode(for: $0) }
        
        // Apply tag filter recursively
        if !saveFilterTag.isEmpty {
            func filterNode(_ node: SaveNode) -> SaveNode? {
                let tag = SaveNotesStore.shared.note(for: node.info.folderName).tag
                let selfMatches = tag == saveFilterTag
                let filteredChildren = node.children.compactMap { filterNode($0) }
                if selfMatches || !filteredChildren.isEmpty {
                    return SaveNode(info: node.info, children: filteredChildren)
                }
                return nil
            }
            roots = roots.compactMap { filterNode($0) }
        }
        
        roots = sortedNodes(roots)
        
        return roots
    }
    
    var availableFilterTags: [String] {
        let allTags = saves.compactMap { SaveNotesStore.shared.note(for: $0.folderName).tag }.filter { !$0.isEmpty }
        return Array(Set(allTags)).sorted()
    }
    
    func setAvatar(forSave folderName: String, iconPath: String) {
        let note = SaveNotesStore.shared.note(for: folderName)
        SaveNotesStore.shared.setNote(for: folderName, tag: note.tag, note: note.note, customIconPath: iconPath)
        objectWillChange.send()
    }
    
    func selectCustomAvatar(forSave folderName: String, completion: ((String) -> Void)? = nil) {
        let urls = filePicking.pickFiles(
            title: L(L10n.Saves.avatarPanelTitle),
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false,
            canChooseDirectories: false
        )
        if let url = urls.first {
            // Copy to app support dir to prevent broken paths
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("StarHubTH/Avatars", isDirectory: true)
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let destURL = supportDir.appendingPathComponent("\(folderName)_\(url.lastPathComponent)")
            try? FileManager.default.copyItem(at: url, to: destURL)
            setAvatar(forSave: folderName, iconPath: destURL.path)
            completion?(destURL.path)
        }
    }
    
    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) {
        if SaveManager.shared.duplicateSave(info: info, newName: newName, newFarm: newFarm) {
            reloadSaves()
            showModal(message: L(L10n.VM.duplicateSaveSuccess))
        } else {
            showModal(message: L(L10n.VM.duplicateSaveError))
        }
    }
    
    func openSaveInFinder(info: SaveGameInfo) {
        SaveManager.shared.openSaveInFinder(info: info)
    }

    // MARK: - Backup Timeline

    func listBackups(for info: SaveGameInfo) -> [SaveBackup] {
        SaveManager.shared.listBackups(for: info)
    }

    func createBackup(info: SaveGameInfo) -> Bool {
        SaveManager.shared.backupSave(info: info)
    }
    
    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) -> Bool {
        if SaveManager.shared.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm) {
            reloadSaves()
            showModal(message: L(L10n.VM.branchSuccess))
            return true
        } else {
            showModal(message: L(L10n.VM.branchError))
            return false
        }
    }

    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) {
        if SaveManager.shared.restoreBackup(backup: backup, info: info) {
            reloadSaves()
            viewingSaveTimeline = nil
            editingSave = nil
            showModal(message: L(L10n.VM.restoreSuccess))
        } else {
            showModal(message: L(L10n.VM.restoreError))
        }
    }

    func deleteBackup(_ backup: SaveBackup) -> Bool {
        SaveManager.shared.deleteBackup(backup)
    }

    // MARK: - Save Notes

    func getNote(for folderName: String) -> SaveNote {
        SaveNotesStore.shared.note(for: folderName)
    }

    func setNote(for folderName: String, tag: String, note: String) {
        // Preserve existing customIconPath
        let existing = SaveNotesStore.shared.note(for: folderName)
        SaveNotesStore.shared.setNote(for: folderName, tag: tag, note: note, customIconPath: existing.customIconPath)
        objectWillChange.send()
    }

    // MARK: - Backup & Management
    func backupAllSaves() {
        let home = NSHomeDirectory()
        let savesDir = "\(home)/.config/StardewValley/Saves"
        let desktopDir = "\(home)/Desktop"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let zipPath = "\(desktopDir)/StardewSaves_Backup_\(timestamp).zip"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipPath, "."]
        process.currentDirectoryURL = URL(fileURLWithPath: savesDir)
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                showModal(message: String(format: L(L10n.VM.backupSavesSuccess), zipPath))
            } else {
                showModal(message: L(L10n.VM.zipSavesError))
            }
        } catch {
            showModal(message: L(L10n.VM.cannotRunZip))
        }
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
        let home = NSHomeDirectory()
        let savesDir = URL(fileURLWithPath: "\(home)/.config/StardewValley/Saves")
        NSWorkspace.shared.open(savesDir)
    }
    
    // MARK: - Mod Profiles
    func loadProfiles() {
        let loaded = ProfileManager.shared.loadProfiles()
        self.modProfiles = loaded.profiles
        self.activeProfileId = loaded.activeId
    }
    
    func saveProfiles() {
        ProfileManager.shared.saveProfiles(modProfiles, activeProfileId: activeProfileId)
    }
    
    func createProfile(name: String) {
        // Snapshot the currently enabled mods into the new profile
        let currentEnabledIds = mods
            .flatMap { mod -> [ModItem.UniqueID] in
                if case .group(let children) = mod.kind {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.rawValue.isEmpty }

        let newProfile = ModProfile(name: name, enabledModIds: currentEnabledIds)
        modProfiles.append(newProfile)
        saveProfiles()
        // Do NOT applyProfile here — just save so the user can edit it first
        activeProfileId = newProfile.id
        saveProfiles()
    }
    
    func deleteProfile(id: UUID) {
        modProfiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = nil
        }
        saveProfiles()
    }
    
    func updateProfile(id: UUID, newName: String, enabledModIds: [ModItem.UniqueID]) {
        if let index = modProfiles.firstIndex(where: { $0.id == id }) {
            modProfiles[index].name = newName
            modProfiles[index].enabledModIds = enabledModIds
            saveProfiles()

            // If this is the active profile, apply the new mod selection to the filesystem
            if activeProfileId == id {
                applyProfileToFilesystem(profile: modProfiles[index])
            }
        }
    }

    func applyProfile(id: UUID?) {
        guard let id = id, let profile = modProfiles.first(where: { $0.id == id }) else {
            activeProfileId = nil
            saveProfiles()
            return
        }

        // If already active, just sync stored list from current filesystem (no file moves)
        if activeProfileId == id {
            syncActiveProfileIds()
            return
        }

        let success = applyProfileToFilesystem(profile: profile)
        if success {
            activeProfileId = id
            saveProfiles()
            self.log(String(format: L(L10n.VM.switchProfile), profile.name))
        } else {
            showModal(message: L(L10n.VM.profileApplyError))
        }
    }

    /// Actually move mod files to match the given profile's enabledModIds.
    @discardableResult
    private func applyProfileToFilesystem(profile: ModProfile) -> Bool {
        let success = ProfileManager.shared.applyProfileToFilesystem(profile: profile, mods: mods, gameDir: gameDir)
        self.scanMods()
        self.syncActiveProfileIds()
        return success
    }

    /// Compute which uniqueIds should be added/removed when toggling a mod in a profile,
    /// using the same chain logic as toggleMod. Works on an in-memory set (no file I/O).
    /// - Parameters:
    ///   - mod: The mod being toggled (can be a group or single mod)
    ///   - enable: true = enabling, false = disabling
    ///   - currentEnabled: the current set of enabled uniqueIds in the profile
    /// - Returns: A new set with the chain applied
    func applyChainToSet(mod: ModItem, enable: Bool, currentEnabled: Set<ModItem.UniqueID>) -> Set<ModItem.UniqueID> {
        ModGraph.enabledIDs(
            after: mod,
            enabling: enable,
            from: currentEnabled,
            in: mods,
            chainingDependencies: chainToggleDependencies
        )
    }

    /// Call this after any toggleMod so the profile stays up to date.
    func syncActiveProfileIds() {
        guard let id = activeProfileId,
              let index = modProfiles.firstIndex(where: { $0.id == id }) else { return }

        let actualEnabledIds = mods
            .flatMap { mod -> [ModItem.UniqueID] in
                if case .group(let children) = mod.kind {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.rawValue.isEmpty }

        modProfiles[index].enabledModIds = actualEnabledIds
        saveProfiles()
    }


    // MARK: - Mod Pack Sharing
    
    func exportModPack(name: String) -> URL? {
        let packMods = mods.flatMap { mod -> [StarHubPackMod] in
            if case .group(let children) = mod.kind {
                return children.filter { $0.isEnabled }.map {
                    let nexusId = Int($0.nexusUrl.components(separatedBy: "/").last ?? "").map { ModItem.NexusID(rawValue: $0) }
                    return StarHubPackMod(name: $0.name, uniqueId: $0.uniqueId, version: $0.version, nexusId: nexusId)
                }
            }
            if mod.isEnabled {
                let nexusId = Int(mod.nexusUrl.components(separatedBy: "/").last ?? "").map { ModItem.NexusID(rawValue: $0) }
                return [StarHubPackMod(name: mod.name, uniqueId: mod.uniqueId, version: mod.version, nexusId: nexusId)]
            }
            return []
        }
        
        let pack = StarHubPack(packName: name, author: steamUsername.isEmpty ? "Player" : steamUsername, description: nil, mods: packMods)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(pack) else { return nil }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "\(name.replacingOccurrences(of: " ", with: "_")).starhubpack"
        savePanel.canCreateDirectories = true
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try data.write(to: url)
                return url
            } catch {
                showModal(message: L(L10n.VM.packSaveFailed))
            }
        }
        return nil
    }
    
    func importModPack(from url: URL) -> StarHubPack? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(StarHubPack.self, from: data)
        } catch {
            print("Failed to decode Mod Pack: \(error)")
            return nil
        }
    }
    
    func importCollectionFromURL(_ urlString: String, completion: @escaping (StarHubPack?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let path = url.path
        let components = path.components(separatedBy: "/")
        // Extract slug from e.g. /stardewvalley/collections/tckf0m
        var slug = ""
        if let idx = components.firstIndex(of: "collections"), idx + 1 < components.count {
            slug = components[idx + 1]
        }
        
        if slug.isEmpty {
            completion(nil)
            return
        }
        
        let apiKey = nexusApiKey
        if apiKey.isEmpty {
            showModal(message: L(L10n.VM.collectionApiKeyRequired))
            completion(nil)
            return
        }
        
        self.log("Fetching collection metadata for slug: \(slug)...")
        LiveNexusAPIClient.shared.getCollectionGraph(slug: slug, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let collection):
                    let packMods = collection.latestPublishedRevision?.modFiles?.compactMap { modFile -> StarHubPackMod? in
                        guard let detail = modFile.file, let modDetail = detail.mod else { return nil }
                        // Format mod's updatedAt as relative string
                        var modUpdated: String? = nil
                        if let rawDate = modDetail.updatedAt {
                            let iso = ISO8601DateFormatter()
                            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            if let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate) {
                                let rel = RelativeDateTimeFormatter()
                                rel.unitsStyle = .abbreviated
                                modUpdated = rel.localizedString(for: date, relativeTo: Date())
                            }
                        }
                        return StarHubPackMod(
                            name: modDetail.name,
                            uniqueId: ModItem.UniqueID(rawValue: "nexus_\(modDetail.modId)"),
                            version: detail.version ?? "",
                            nexusId: ModItem.NexusID(rawValue: modDetail.modId),
                            modAuthor: modDetail.author,
                            modDownloads: modDetail.downloads,
                            modUpdatedAt: modUpdated,
                            thumbnailUrl: modDetail.thumbnailUrl
                        )
                    } ?? []
                    
                    // Format updatedAt from ISO8601 to readable date string
                    var updatedAtDisplay: String? = nil
                    if let rawDate = collection.updatedAt {
                        let iso = ISO8601DateFormatter()
                        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate) {
                            let rel = RelativeDateTimeFormatter()
                            rel.unitsStyle = .abbreviated
                            updatedAtDisplay = rel.localizedString(for: date, relativeTo: Date())
                        }
                    }
                    
                    let gameVersion = collection.latestPublishedRevision?.gameVersions?.first?.reference
                    
                    var pack = StarHubPack(
                        packName: collection.name,
                        author: collection.user?.name ?? "Unknown",
                        description: collection.summary,
                        mods: packMods
                    )
                    pack.imageUrl = collection.tileImage?.url
                    pack.revision = collection.latestPublishedRevision?.revisionNumber
                    pack.updatedAt = updatedAtDisplay
                    pack.gameVersion = gameVersion
                    pack.totalDownloads = collection.totalDownloads
                    pack.endorsements = collection.endorsements
                    completion(pack)
                case .failure(_):
                    self.showModal(message: self.L(L10n.VM.collectionFetchFailed))
                    completion(nil)
                }
            }
        }
    }
    
    func downloadModFromNexus(nexusId: ModItem.NexusID, fileId: Int? = nil, completion: @escaping (Bool) -> Void) {
        let apiKey = nexusApiKey
        if apiKey.isEmpty {
            completion(false)
            return
        }

        let targetFileId: Int

        if let fId = fileId {
            targetFileId = fId
            startDownload(nexusId: nexusId, fileId: targetFileId, apiKey: apiKey, completion: completion)
        } else {
            self.log("Fetching latest file for Nexus Mod #\(nexusId.rawValue)...")
            LiveNexusAPIClient.shared.getModFiles(modId: nexusId.rawValue, apiKey: apiKey) { result in
                switch result {
                case .success(let response):
                    guard let latestFile = response.files.first else {
                        self.log("No files found for Nexus Mod #\(nexusId.rawValue).")
                        completion(false)
                        return
                    }
                    self.startDownload(nexusId: nexusId, fileId: latestFile.fileId, apiKey: apiKey, completion: completion)
                case .failure(let error):
                    self.log("Failed to fetch mod files: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    private func startDownload(nexusId: ModItem.NexusID, fileId: Int, apiKey: String, completion: @escaping (Bool) -> Void) {
        self.log("Requesting download link for file #\(fileId)...")
        LiveNexusAPIClient.shared.getDownloadLink(modId: nexusId.rawValue, fileId: fileId, apiKey: apiKey) { linkResult in
                    switch linkResult {
                    case .success(let links):
                        guard let firstLink = links.first, let downloadURL = URL(string: firstLink.URI) else {
                            self.log("No valid download links found.")
                            completion(false)
                            return
                        }

                        self.log("Starting download for Nexus Mod #\(nexusId.rawValue)...")
                        let task = URLSession.shared.downloadTask(with: downloadURL) { localURL, response, error in
                            if let error = error {
                                self.log("Download failed: \(error.localizedDescription)")
                                completion(false)
                                return
                            }
                            
                            guard let localURL = localURL else {
                                completion(false)
                                return
                            }
                            
                            // Move to a temp zip file
                            let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                            do {
                                try FileManager.default.moveItem(at: localURL, to: tempZipURL)
                                DispatchQueue.main.async {
                                    // Pass completion into installModFromZip so it fires AFTER extraction finishes
                                    self.installModFromZip(url: tempZipURL, completion: completion)
                                }
                            } catch {
                                self.log("Failed to process downloaded file: \(error.localizedDescription)")
                                completion(false)
                            }
                        }
                        task.resume()
                        
                    case .failure(let error):
                        self.log("Failed to get download link (Premium required?): \(error.localizedDescription)")
                        completion(false)
                    }
        }
    }
}

import Foundation
import Cocoa
import SwiftUI

final class StarHubTHViewModel: ObservableObject {
    @Published var saveViewMode: SaveViewMode = .list
    @Published var saveSortOption: SaveSortOption = .lastPlayed
    @Published var saveFilterTag: String = ""

    @Published var gameDir: String = "" {
        didSet {
            UserDefaults.standard.set(gameDir, forKey: "gameDir")
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
    func resolveDependencyStatus(for uniqueId: String) -> DependencyStatus {
        ModGraph.dependencyStatus(for: uniqueId, in: mods)
    }

    /// Resolves install status for a mod pack mod.
    /// Tries Nexus ID match first (via nexusUrl), then falls back to SMAPI uniqueId.
    func resolvePackModStatus(nexusId: Int?, uniqueId: String) -> PackModStatus {
        ModGraph.packModStatus(nexusID: nexusId, uniqueId: uniqueId, in: mods)
    }
    
    // Custom Tags
    var customModTags: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "customModTags") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "customModTags") }
    }
    
    func setCustomTag(for modId: String, tag: String, shouldRefresh: Bool = true) {
        var tags = customModTags
        tags[modId] = tag
        customModTags = tags
        if shouldRefresh { refresh() }
    }
    
    func resetCustomTag(for modId: String) {
        var tags = customModTags
        tags.removeValue(forKey: modId)
        customModTags = tags
        refresh()
    }
    
    func syncTagFromNexus(for mod: ModItem, shouldRefresh: Bool = true, completion: @escaping (Bool) -> Void) {
        let apiKey = nexusApiKey
        guard !apiKey.isEmpty, let url = URL(string: mod.nexusUrl), let modId = Int(url.lastPathComponent) else {
            completion(false)
            return
        }
        
        NexusAPIService.shared.getModInfo(modId: modId, apiKey: apiKey) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let info):
                    if let categoryId = info.categoryId {
                        let newTag = NexusAPIService.categoryTag(from: categoryId)
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
    
    // Thai Translation Hub State
    @Published var thaiTranslations: [ThaiTranslationMod] = []
    @Published var viewingThaiMod: ThaiTranslationMod? = nil
    
    @Published var logOutput: String = ""
    @Published var logEntries: [LogEntry] = []
    @Published var isReadingSMAPILog: Bool = false
    private var smapiLogFileHandle: FileHandle? = nil
    @Published var smapiLogTimer: Timer? = nil
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
    
    private static let supportedLanguages = Set(["en", "th"])
    private static func normalizedLanguage(_ language: String?) -> String {
        guard let language, supportedLanguages.contains(language) else { return defaultLanguage }
        return language
    }
    private static var defaultLanguage: String {
        Locale.preferredLanguages.contains { $0.lowercased().hasPrefix("th") } ? "th" : "en"
    }
    
    @Published var currentLanguage: String = StarHubTHViewModel.normalizedLanguage(UserDefaults.standard.string(forKey: "currentLanguage")) {
        didSet {
            if !Self.supportedLanguages.contains(currentLanguage) {
                currentLanguage = "en"
                return
            }
            UserDefaults.standard.set(currentLanguage, forKey: "currentLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Returns a locale- and calendar-aware DateFormatter for short dates.
    /// - English → en_US + Gregorian → M/d/yyyy  (USA format, e.g. 3/25/2024)
    /// - Thai    → th_TH + Buddhist  → d/M/yyyy  (Thai BE, e.g. 25/3/2569)
    func makeDateFormatter(dateStyle: DateFormatter.Style = .short) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        if currentLanguage == "th" {
            formatter.locale = Locale(identifier: "th_TH")
            formatter.calendar = Calendar(identifier: .buddhist)
            // Explicit format: day/month/year in Buddhist Era
            if dateStyle == .medium {
                formatter.dateFormat = "d MMM yyyy"
            } else {
                formatter.dateFormat = "d/M/yyyy"
            }
        } else {
            formatter.locale = Locale(identifier: "en_US")
            formatter.calendar = Calendar(identifier: .gregorian)
            // USA format: month/day/year
            if dateStyle == .medium {
                formatter.dateFormat = "MMM d, yyyy"
            } else {
                formatter.dateFormat = "M/d/yyyy"
            }
        }
        return formatter
    }
    
    
    @Published var modProfiles: [ModProfile] = []
    @Published var activeProfileId: UUID? = nil

    /// When true, toggling a mod also cascades to its dependencies / dependents.
    /// Persisted in UserDefaults so SettingsView @AppStorage stays in sync.
    var chainToggleDependencies: Bool {
        get { UserDefaults.standard.object(forKey: "chainToggleDependencies") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "chainToggleDependencies") }
    }
    
    var nexusApiKey: String {
        get { UserDefaults.standard.string(forKey: "nexusApiKey") ?? "" }
    }
    
    @Published var downloadingMods: Set<String> = []
    
    let smapiInstaller = SmapiInstaller()
    
    init() {
        // Force sync AppleLanguages with currentLanguage at startup
        let savedLang = Self.normalizedLanguage(UserDefaults.standard.string(forKey: "currentLanguage"))
        currentLanguage = savedLang
        UserDefaults.standard.set([savedLang], forKey: "AppleLanguages")
        
        // Automatically retrieve saved game path, or attempt to find the default Steam path on Mac
        let savedPath = UserDefaults.standard.string(forKey: "gameDir") ?? ""
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
                self.downloadModFromNexus(nexusId: modId, fileId: fileId) { success in
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
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            self.gameDir = panel.url?.path ?? ""
            UserDefaults.standard.set(self.gameDir, forKey: "gameDir")
            scanMods()
            checkSmapiVersion()
        }
    }
    
    // Helper to force localization using the currently selected language bundle
    func localizedString(for key: String) -> String {
        // Build the lproj URL directly from resourceURL (more reliable for swiftc-built apps)
        if let resourceURL = Bundle.main.resourceURL {
            let lprojURL = resourceURL.appendingPathComponent("\(currentLanguage).lproj")
            if let bundle = Bundle(url: lprojURL) {
                // Must call localizedString directly on the bundle object
                let result = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
                if result != "__MISSING__" { return result }
            }
        }
        // Last resort: return key so missing translations are visible
        return key
    }

    /// Typed-key shorthand. Prefer this over localizedString(for:) with raw strings.
    /// Example: vm.L(L10n.Mods.enabled)
    func L(_ key: String) -> String {
        return localizedString(for: key)
    }
    
    func localizedTag(_ tag: String) -> String {
        let rawTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawTag.isEmpty { return rawTag }
        
        switch rawTag {
        case "Content Patcher": return L(L10n.Tags.contentPatcher)
        case "Framework": return L(L10n.Tags.framework)
        case "Cosmetic": return L(L10n.Tags.cosmetic)
        case "NPC": return L(L10n.Tags.npc)
        case "UI": return L(L10n.Tags.ui)
        case "Audio": return L(L10n.Tags.audio)
        case "Map": return L(L10n.Tags.map)
        case "Gameplay": return L(L10n.Tags.gameplay)
        case "Translation": return L(L10n.Tags.translation)
        case "Other": return L(L10n.Tags.other)
        case "tag_nexus_2": return L(L10n.Tags.nexus2)
        case "tag_nexus_3": return L(L10n.Tags.nexus3)
        case "tag_nexus_4": return L(L10n.Tags.nexus4)
        case "tag_nexus_5": return L(L10n.Tags.nexus5)
        case "tag_nexus_6": return L(L10n.Tags.nexus6)
        case "tag_nexus_7": return L(L10n.Tags.nexus7)
        case "tag_nexus_8": return L(L10n.Tags.nexus8)
        case "tag_nexus_9": return L(L10n.Tags.nexus9)
        case "tag_nexus_10": return L(L10n.Tags.nexus10)
        case "tag_nexus_11": return L(L10n.Tags.nexus11)
        case "tag_nexus_12": return L(L10n.Tags.nexus12)
        case "tag_nexus_13": return L(L10n.Tags.nexus13)
        case "tag_nexus_14": return L(L10n.Tags.nexus14)
        case "tag_nexus_15": return L(L10n.Tags.nexus15)
        case "tag_nexus_16": return L(L10n.Tags.nexus16)
        case "tag_nexus_17": return L(L10n.Tags.nexus17)
        case "tag_nexus_18": return L(L10n.Tags.nexus18)
        case "tag_nexus_19": return L(L10n.Tags.nexus19)
        case "tag_nexus_20": return L(L10n.Tags.nexus20)
        case "tag_nexus_21": return L(L10n.Tags.nexus21)
        case "tag_nexus_22": return L(L10n.Tags.nexus22)
        case "tag_nexus_23": return L(L10n.Tags.nexus23)
        case "tag_nexus_24": return L(L10n.Tags.nexus24)
        case "tag_nexus_25": return L(L10n.Tags.nexus25)
        case "tag_nexus_26": return L(L10n.Tags.nexus26)
        case "tag_nexus_27": return L(L10n.Tags.nexus27)
        default: return tag
        }
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
                ($0.folderName.lowercased() == "stardew valley - thai" ||
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
    func getMissingDependencies(for mod: ModItem) -> [String] {
        ModGraph.missingDependencies(for: mod, in: mods)
    }
    
    // Toggle Mod Status (Enabled / Disabled)
    func toggleMod(_ mod: ModItem) {
        // Helper to find the top-level folder that contains a given uniqueId
        func getTopLevelFolder(for uniqueId: String) -> String? {
            for m in self.mods {
                if !m.isGroup && m.uniqueId.caseInsensitiveCompare(uniqueId) == .orderedSame {
                    return m.folderName
                } else if m.isGroup, let children = m.children {
                    if children.contains(where: { $0.uniqueId.caseInsensitiveCompare(uniqueId) == .orderedSame }) {
                        return m.folderName
                    }
                }
            }
            return nil
        }
        
        // Helper to get all dependencies of a top-level folder (including its children)
        func getDependencies(for folderName: String) -> [ModDependency] {
            guard let m = self.mods.first(where: { $0.folderName == folderName }) else { return [] }
            if m.isGroup, let children = m.children {
                return children.flatMap { $0.dependencies }
            } else {
                return m.dependencies
            }
        }
        
        var foldersToToggle: Set<String> = [mod.folderName]
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
                    
                    var providedUniqueIds: [String] = []
                    if let m = self.mods.first(where: { $0.folderName == currentFolder }) {
                        if m.isGroup, let children = m.children {
                            providedUniqueIds = children.map { $0.uniqueId }
                        } else {
                            providedUniqueIds = [m.uniqueId]
                        }
                    }
                    
                    for otherMod in self.mods where otherMod.isEnabled && !foldersToToggle.contains(otherMod.folderName) {
                        let otherDeps = getDependencies(for: otherMod.folderName)
                        let requiresCurrent = otherDeps.contains { dep in
                            dep.isRequired && providedUniqueIds.contains { $0.caseInsensitiveCompare(dep.uniqueId) == .orderedSame }
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
            
            let srcPath = ((m.isEnabled ? modsPath : disabledModsPath) as NSString).appendingPathComponent(m.folderName)
            let destFolder = m.isEnabled ? disabledModsPath : modsPath
            let destPath = ((destFolder as NSString).appendingPathComponent(m.folderName) as String)
            
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

    /// Opens an NSOpenPanel — accepts both .zip files AND already-extracted folders.
    func openInstallModPanel() {
        let panel = NSOpenPanel()
        panel.title = L(L10n.Mods.installMod)
        panel.allowedContentTypes = [.init(filenameExtension: "zip")!]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true   // ← also accept extracted folders
        if panel.runModal() == .OK {
            for url in panel.urls {
                installMod(url: url)
            }
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
    
    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: Int) {
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
    @Published var selectedModID: String? = nil {
        didSet {
            if let id = selectedModID, selectedMod?.folderName != id {
                selectedMod = mods.first { $0.folderName == id }
            }
        }
    }

    func log(_ message: String, level: LogLevel = .info) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let entry = LogEntry(timestamp: timestamp, message: message, level: level, source: .app)

        let logString = "[\(timestamp)] \(message)\n"

        // Append to file logger
        DispatchQueue.global(qos: .background).async {
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let logDir = appSupport.appendingPathComponent("StarHubTH")
                try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
                let logFile = logDir.appendingPathComponent("StarHubTH_debug.log")
                if let data = logString.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFile.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFile)
                    }
                }
            }
        }

        if Thread.isMainThread {
            logEntries.append(entry)
            logOutput += logString
        } else {
            DispatchQueue.main.async {
                self.logEntries.append(entry)
                self.logOutput += logString
            }
        }
    }

    // MARK: - SMAPI Real-time Log Reader

    // MARK: - SMAPI Log Reader

    /// Load SMAPI-latest.txt asynchronously when Logs tab is opened.
    func loadSmapiLog() {
        let path = smapiLogPath
        guard FileManager.default.fileExists(atPath: path) else { return }

        isReadingSMAPILog = true

        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = FileManager.default.contents(atPath: path),
                  let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.isReadingSMAPILog = false
                }
                return
            }

            let lines = text.components(separatedBy: .newlines)
            var entries: [LogEntry] = []

            for line in lines {
                if line.hasPrefix("[") {
                    guard let bracketEnd = line.firstIndex(of: "]") else {
                        continue
                    }

                    let header = String(line[line.index(after: line.startIndex)..<bracketEnd])
                    let headerParts = header.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

                    let ts = headerParts.count >= 1 ? headerParts[0] : "—"
                    let levelStr = headerParts.count >= 2 ? headerParts[1] : ""
                    let contextName: String? = {
                        guard headerParts.count >= 3 else { return nil }
                        let name = headerParts[2...].joined(separator: " ")
                        return (name == "SMAPI" || name == "game") ? nil : name
                    }()

                    let level: LogLevel
                    switch levelStr.uppercased() {
                    case "ERROR":  level = .error
                    case "WARN":   level = .warning
                    case "ALERT":  level = .warning
                    case "INFO":   level = .info
                    default:       level = .smapi  // TRACE, DEBUG, etc.
                    }

                    let msgStart = line.index(after: bracketEnd)
                    let message = msgStart < line.endIndex
                        ? String(line[msgStart...]).trimmingCharacters(in: .whitespaces)
                        : ""

                    if !message.isEmpty || contextName != nil {
                        var entry = LogEntry(timestamp: ts, message: message, level: level, source: .smapi)
                        entry.modName = contextName
                        entries.append(entry)
                    }
                } else {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, !entries.isEmpty else { continue }
                    let last = entries.removeLast()
                    let combined = last.message.isEmpty ? trimmed : last.message + "\n" + trimmed
                    var updated = LogEntry(timestamp: last.timestamp, message: combined, level: last.level, source: .smapi)
                    updated.modName = last.modName
                    entries.append(updated)
                }
            }

            DispatchQueue.main.async {
                self.logEntries.append(contentsOf: entries)
                self.isReadingSMAPILog = false
            }
        }
    }

    private var smapiLogPath: String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        return (homeDir as NSString).appendingPathComponent(
            ".config/StardewValley/ErrorLogs/SMAPI-latest.txt"
        )
    }

    func startSmapiLogWatcher() { loadSmapiLog() }
    func stopSmapiLogWatcher() {
        smapiLogTimer?.invalidate()
        smapiLogTimer = nil
        try? smapiLogFileHandle?.close()
        smapiLogFileHandle = nil
    }

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
        #if canImport(AppKit)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = L(L10n.Saves.avatarPanelTitle)
        if panel.runModal() == .OK, let url = panel.url {
            // Copy to app support dir to prevent broken paths
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("StarHubTH/Avatars", isDirectory: true)
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            let destURL = supportDir.appendingPathComponent("\(folderName)_\(url.lastPathComponent)")
            try? FileManager.default.copyItem(at: url, to: destURL)
            setAvatar(forSave: folderName, iconPath: destURL.path)
            completion?(destURL.path)
        }
        #endif
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
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName)
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "")
        let defaultFileName = "\(mod.folderName)_Backup_\(timestamp).zip"
        
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
        let modDir = (basePath as NSString).appendingPathComponent(mod.folderName)
        
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
        guard let url = URL(string: "https://raw.githubusercontent.com/AppleBoiy/stardew-thai-translations/main/README.md") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let content = String(data: data, encoding: .utf8) else { return }
            
            var newTranslations: [ThaiTranslationMod] = []
            let lines = content.components(separatedBy: .newlines)
            var inTable = false
            
            for line in lines {
                if line.starts(with: "| ชื่อม็อด") {
                    inTable = true
                    continue
                }
                if inTable && line.starts(with: "| :---") { continue }
                if inTable && line.starts(with: "|") {
                    let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.count >= 6 {
                        let rawName = parts[1] // **[[CP] Additional Farm Cave](https://...)**
                        var cleanName = rawName.replacingOccurrences(of: "**", with: "")
                        var url = ""
                        
                        // Use regex to extract name and URL: [Name](URL)
                        let pattern = "\\[(.*?)\\]\\((.*?)\\)"
                        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                           let match = regex.firstMatch(in: cleanName, options: [], range: NSRange(location: 0, length: cleanName.utf16.count)) {
                            if let nameRange = Range(match.range(at: 1), in: cleanName) {
                                let extractedName = String(cleanName[nameRange])
                                if let urlRange = Range(match.range(at: 2), in: cleanName) {
                                    url = String(cleanName[urlRange])
                                }
                                cleanName = extractedName
                            }
                        }
                        
                        let author = parts[2]
                        let version = parts[3]
                        let status = parts[4]
                        
                        let rawNexus = parts[5]
                        var nexusUrl = ""
                        if let r1 = rawNexus.range(of: "("), let r2 = rawNexus.range(of: ")") {
                            nexusUrl = String(rawNexus[rawNexus.index(after: r1.lowerBound)..<r2.lowerBound])
                        }
                        
                        let mod = ThaiTranslationMod(
                            name: cleanName,
                            author: author,
                            version: version,
                            status: status,
                            url: url,
                            nexusUrl: nexusUrl
                        )
                        newTranslations.append(mod)
                    }
                } else if inTable && line.isEmpty {
                    inTable = false
                }
            }
            
            DispatchQueue.main.async {
                self.thaiTranslations = newTranslations
                self.evaluateThaiTranslationStatus()
            }
        }.resume()
    }
    
    func evaluateThaiTranslationStatus() {
        guard !gameDir.isEmpty else { return }
        let fm = FileManager.default
        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")
        
        for i in 0..<thaiTranslations.count {
            // Very simple check: does any mod folder contain an i18n/th.json?
            // AND does the folder name sort of match the mod name?
            let nameToCheck = thaiTranslations[i].name.replacingOccurrences(of: "[CP]", with: "").trimmingCharacters(in: .whitespaces)
            var foundTranslation = false
            var foundOriginal = false
            for mod in mods {
                if mod.name.localizedCaseInsensitiveContains(nameToCheck) || nameToCheck.localizedCaseInsensitiveContains(mod.name) {
                    foundOriginal = true
                    
                    let thJsonPath = (modsDir as NSString).appendingPathComponent("\(mod.folderName)/i18n/th.json")
                    let cpThJsonPath = (modsDir as NSString).appendingPathComponent("\(mod.folderName)/[CP] \(mod.folderName)/i18n/th.json") // Handle nested [CP]
                    
                    if fm.fileExists(atPath: thJsonPath) || fm.fileExists(atPath: cpThJsonPath) {
                        foundTranslation = true
                    } else if mod.isGroup {
                        for child in mod.children ?? [] {
                            let childThJsonPath = (modsDir as NSString).appendingPathComponent("\(child.folderName)/i18n/th.json")
                            let childCpThJsonPath = (modsDir as NSString).appendingPathComponent("\(child.folderName)/[CP] \(child.folderName)/i18n/th.json")
                            if fm.fileExists(atPath: childThJsonPath) || fm.fileExists(atPath: childCpThJsonPath) {
                                foundTranslation = true
                                break
                            }
                        }
                    }
                }
            }
            thaiTranslations[i].availability = foundTranslation ? .installed : (foundOriginal ? .downloadable : .baseModMissing)
        }
        
        // Sort installed mods first, then alphabetically
        thaiTranslations.sort { mod1, mod2 in
            if mod1.isInstalled != mod2.isInstalled {
                return mod1.isInstalled
            }
            return mod1.name.localizedStandardCompare(mod2.name) == .orderedAscending
        }
    }
    
    func installThaiTranslation(mod: ThaiTranslationMod) {
        guard !gameDir.isEmpty else { return }
        
        let modsDir = (gameDir as NSString).appendingPathComponent("Mods")
        let zipName = "\(mod.name.replacingOccurrences(of: "[CP] ", with: "")) - Thai Translation.zip"
        
        showModal(message: String(format: L(L10n.VM.downloadingTranslation), mod.name))
        
        let apiUrl = URL(string: "https://api.github.com/repos/AppleBoiy/stardew-thai-translations/releases?per_page=100")!
        var request = URLRequest(url: apiUrl)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async { self.showModal(message: String(format: self.L(L10n.VM.downloadFailed), error.localizedDescription)) }
                return
            }
            
            guard let data = data,
                  let releases = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                DispatchQueue.main.async { self.showModal(message: self.L(L10n.VM.downloadFailed) + " (Invalid API Response)") }
                return
            }
            
            var targetDownloadUrl: URL? = nil
            
            for release in releases {
                if let assets = release["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String {
                            let normalizedAssetName = name.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
                            let normalizedZipName = zipName.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: " ", with: "")
                            
                            if normalizedAssetName == normalizedZipName,
                               let browserDownloadUrl = asset["browser_download_url"] as? String,
                               let url = URL(string: browserDownloadUrl) {
                                targetDownloadUrl = url
                                break
                            }
                        }
                    }
                }
                if targetDownloadUrl != nil { break }
            }
            
            guard let downloadUrl = targetDownloadUrl else {
                DispatchQueue.main.async { self.showModal(message: self.L(L10n.VM.downloadFailed) + " (Zip not found in releases)") }
                return
            }
            
            let task = URLSession.shared.downloadTask(with: downloadUrl) { localUrl, response, error in
                if let error = error {
                    DispatchQueue.main.async { self.showModal(message: String(format: self.L(L10n.VM.downloadFailed), error.localizedDescription)) }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    DispatchQueue.main.async { self.showModal(message: self.L(L10n.VM.downloadFailed) + " (HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0))") }
                    return
                }
                
                guard let localUrl = localUrl else { return }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-o", localUrl.path, "-d", modsDir]
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 {
                            self.showModal(message: String(format: self.L(L10n.VM.installThaiSuccess), mod.name))
                            self.evaluateThaiTranslationStatus()
                        } else {
                            self.showModal(message: self.L(L10n.VM.unzipError))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.showModal(message: String(format: self.L(L10n.VM.unzipFailed), error.localizedDescription))
                    }
                }
            }
            task.resume()
        }.resume()
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
            .flatMap { mod -> [String] in
                if mod.isGroup, let children = mod.children {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.isEmpty }

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
    
    func updateProfile(id: UUID, newName: String, enabledModIds: [String]) {
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
    func applyChainToSet(mod: ModItem, enable: Bool, currentEnabled: Set<String>) -> Set<String> {
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
            .flatMap { mod -> [String] in
                if mod.isGroup, let children = mod.children {
                    return children.filter { $0.isEnabled }.map { $0.uniqueId }
                }
                return mod.isEnabled ? [mod.uniqueId] : []
            }
            .filter { !$0.isEmpty }

        modProfiles[index].enabledModIds = actualEnabledIds
        saveProfiles()
    }


    // MARK: - Mod Pack Sharing
    
    func exportModPack(name: String) -> URL? {
        let packMods = mods.flatMap { mod -> [StarHubPackMod] in
            if mod.isGroup, let children = mod.children {
                return children.filter { $0.isEnabled }.map {
                    let nexusId = Int($0.nexusUrl.components(separatedBy: "/").last ?? "")
                    return StarHubPackMod(name: $0.name, uniqueId: $0.uniqueId, version: $0.version, nexusId: nexusId)
                }
            }
            if mod.isEnabled {
                let nexusId = Int(mod.nexusUrl.components(separatedBy: "/").last ?? "")
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
        NexusAPIService.shared.getCollectionGraph(slug: slug, apiKey: apiKey) { result in
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
                            uniqueId: "nexus_\(modDetail.modId)",
                            version: detail.version ?? "",
                            nexusId: modDetail.modId,
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
    
    func downloadModFromNexus(nexusId: Int, fileId: Int? = nil, completion: @escaping (Bool) -> Void) {
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
            self.log("Fetching latest file for Nexus Mod #\(nexusId)...")
            NexusAPIService.shared.getModFiles(modId: nexusId, apiKey: apiKey) { result in
                switch result {
                case .success(let response):
                    guard let latestFile = response.files.first else {
                        self.log("No files found for Nexus Mod #\(nexusId).")
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
    
    private func startDownload(nexusId: Int, fileId: Int, apiKey: String, completion: @escaping (Bool) -> Void) {
        self.log("Requesting download link for file #\(fileId)...")
        NexusAPIService.shared.getDownloadLink(modId: nexusId, fileId: fileId, apiKey: apiKey) { linkResult in
                    switch linkResult {
                    case .success(let links):
                        guard let firstLink = links.first, let downloadURL = URL(string: firstLink.URI) else {
                            self.log("No valid download links found.")
                            completion(false)
                            return
                        }
                        
                        self.log("Starting download for Nexus Mod #\(nexusId)...")
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

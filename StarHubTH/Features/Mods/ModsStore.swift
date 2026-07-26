import Foundation
import UniformTypeIdentifiers

/// Phase 4.7. The largest store: owns the installed mod list, its filters, custom tags,
/// mod scanning, enable/disable toggling, installation, and Mods-directory backup/restore.
///
/// `gameDir`, `chainToggleDependencies`, `showModal`, `log`, and `refresh` aren't owned
/// here — they belong to AppEnvironment (4.8) or stay on the ViewModel (showModal/log
/// don't have their own store; refresh is cross-store orchestration) — so the affected
/// methods take them as parameters/closures, same approach as every store since 4.3.
/// `syncActiveProfileIds` (ProfilesStore's) is threaded through `toggleMod` the same way.
///
/// Split across ModsStore.swift/+Tags/+Toggle/+Install/+Backup.swift (§ file-size
/// convention) — stored properties/init/dependency-resolution/scanning stay here since
/// Swift requires stored properties in the main declaration; each extension file owns one
/// MARK section from the original file, unchanged. No `private` helper is called across
/// files — each section's private methods are only used within that same section.
@MainActor
final class ModsStore: ObservableObject {
    @Published var mods: [Mod] = [] // STANDARDS-EXCEPTION: §8 — ModsStoreTests seeds fixture state directly

    @Published var modFilterStatus: ModFilterStatus = .all // STANDARDS-EXCEPTION: §8 — StatusFilterPills writes it directly (filter pill taps)
    @Published var modFilterTag: String = "" // STANDARDS-EXCEPTION: §8 — ModControlsBar writes it directly (tag filter menu)
    @Published var modFilterDate: ModFilterDate = .all // STANDARDS-EXCEPTION: §8 — ModControlsBar writes it directly (date filter menu)
    @Published var modSortOption: ModSortOption = .name // STANDARDS-EXCEPTION: §8 — ModControlsBar writes it directly (sort menu)

    @Published private(set) var outOfDateMods: [ModUpdateInfo] = []
    @Published private(set) var smapiErrors: [String] = []
    @Published private(set) var isThaiTranslationInstalled: Bool = false

    // `private`/`private(set)` are file-scoped in Swift, not type-scoped, so a property
    // this type's own (relocated) methods still need to write can't use private(set) once
    // the writing method lives in a different extension file — still unreachable from
    // Views/tests either way.
    @Published var isSyncingAllTags = false // STANDARDS-EXCEPTION: §8 — written by ModsStore+Tags.swift
    @Published var syncAllTagsProgress: Double = 0.0 // STANDARDS-EXCEPTION: §8 — written by ModsStore+Tags.swift

    @Published var editingModConfig: Mod? // STANDARDS-EXCEPTION: §8 — ModCardView/ModListRow/MainView write it directly (open/close config editor sheet)
    @Published var viewingModDetails: Mod? // STANDARDS-EXCEPTION: §8 — ModCardView/ModListRow/MainView write it directly (open/close details sheet)

    @Published var downloadingMods: Set<String> = [] // STANDARDS-EXCEPTION: §8 — written by ModsStore+Install.swift (file-scoped private(set), see isSyncingAllTags above)
    @Published var isInstallingMod: Bool = false // STANDARDS-EXCEPTION: §8 — written by ModsStore+Install.swift (file-scoped private(set), see isSyncingAllTags above)

    @Published private(set) var selectedMod: Mod? {
        didSet {
            if let mod = selectedMod, selectedModID != mod.folderName {
                selectedModID = mod.folderName
            }
        }
    }
    @Published var selectedModID: Mod.FolderName? { // STANDARDS-EXCEPTION: §8 — MainView writes it directly (sidebar selection)
        didSet {
            if let id = selectedModID, selectedMod?.folderName != id {
                selectedMod = mods.first { $0.folderName == id }
            }
        }
    }

    private let modScanning: ModScanning
    let modInstalling: ModInstalling
    let nexusAPIClient: NexusAPIClient
    let filePicking: FilePicking
    let preferenceStoring: PreferenceStoring
    let localization: LocalizationStore

    init(
        modScanning: ModScanning,
        modInstalling: ModInstalling,
        nexusAPIClient: NexusAPIClient,
        filePicking: FilePicking,
        preferenceStoring: PreferenceStoring,
        localization: LocalizationStore
    ) {
        self.modScanning = modScanning
        self.modInstalling = modInstalling
        self.nexusAPIClient = nexusAPIClient
        self.filePicking = filePicking
        self.preferenceStoring = preferenceStoring
        self.localization = localization
    }

    // MARK: - Dependency resolution (pure, delegates to ModGraph)

    func resolveDependencyStatus(for uniqueId: Mod.UniqueID) -> DependencyStatus {
        ModGraph.dependencyStatus(for: uniqueId, in: mods)
    }

    func resolvePackModStatus(nexusId: Mod.NexusID?, uniqueId: Mod.UniqueID) -> PackModStatus {
        ModGraph.packModStatus(nexusID: nexusId, uniqueId: uniqueId, in: mods)
    }

    func missingDependencies(for mod: Mod) -> [Mod.UniqueID] {
        ModGraph.missingDependencies(for: mod, in: mods)
    }

    // MARK: - Scanning

    func scanMods(gameDir: String) {
        let scannedMods = modScanning.scan(gameDir: gameDir, customModTags: customModTags)

        parseSMAPILog(gameDir: gameDir)

        mods = scannedMods
        if selectedMod == nil, let first = mods.first {
            selectedMod = first
        }
        isThaiTranslationInstalled = scannedMods.contains {
            ($0.folderName.rawValue.lowercased() == "stardew valley - thai" ||
            $0.name.localizedCaseInsensitiveContains("thai")) && $0.isEnabled
        }
    }

    // Parses the SMAPI-latest.txt log for updates and errors
    func parseSMAPILog(gameDir: String) {
        guard !gameDir.isEmpty else { return }

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let logPath = (homeDir as NSString).appendingPathComponent(".config/StardewValley/ErrorLogs/SMAPI-latest.txt")
        guard FileManager.default.fileExists(atPath: logPath),
              let logContent = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            outOfDateMods = []
            smapiErrors = []
            return
        }

        let result = SmapiLogParser.parse(logContent: logContent)
        outOfDateMods = result.outOfDateMods
        smapiErrors = result.errors
    }
}

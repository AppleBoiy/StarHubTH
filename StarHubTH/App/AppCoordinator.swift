import Foundation

/// Phase 4.9. Every action that needs more than one store — most of what used to live
/// directly on `StarHubTHViewModel` once its 1:1 store-forwarding properties are excluded.
/// Owns zero `@Published` state of its own; every method here reads from and calls into
/// the 8 stores it holds a reference to, so it can never itself drift out of sync with
/// them. `ObservableObject` only so it's `@EnvironmentObject`-injectable — nothing here
/// publishes.
@MainActor
final class AppCoordinator: ObservableObject {
    let localizationStore: LocalizationStore
    let logStore: LogStore
    let thaiHubStore: ThaiHubStore
    let profilesStore: ProfilesStore
    let modPacksStore: ModPacksStore
    let savesStore: SavesStore
    let modsStore: ModsStore
    let appEnvironment: AppEnvironment
    let alertStore: AlertStore

    private let filePicking: FilePicking
    private let preferenceStoring: PreferenceStoring

    init(
        localizationStore: LocalizationStore,
        logStore: LogStore,
        thaiHubStore: ThaiHubStore,
        profilesStore: ProfilesStore,
        modPacksStore: ModPacksStore,
        savesStore: SavesStore,
        modsStore: ModsStore,
        appEnvironment: AppEnvironment,
        alertStore: AlertStore,
        filePicking: FilePicking,
        preferenceStoring: PreferenceStoring
    ) {
        self.localizationStore = localizationStore
        self.logStore = logStore
        self.thaiHubStore = thaiHubStore
        self.profilesStore = profilesStore
        self.modPacksStore = modPacksStore
        self.savesStore = savesStore
        self.modsStore = modsStore
        self.appEnvironment = appEnvironment
        self.alertStore = alertStore
        self.filePicking = filePicking
        self.preferenceStoring = preferenceStoring
    }

    // MARK: - URL / game dir

    func handleOpenURL(_ url: URL) async {
        logStore.log("Opened with URL: \(url.absoluteString)", level: .info)

        guard url.scheme?.lowercased() == "nxm" else {
            logStore.log("Rejected: Not an NXM scheme")
            return
        }

        if appEnvironment.nexusApiKey.isEmpty {
            alertStore.show(localizationStore.L(L10n.VM.nexusPremiumRequired))
            return
        }

        guard let result = NXMParser.parse(url: url) else {
            logStore.log("Unsupported or unrecognized NXM link format: \(url.absoluteString)")
            return
        }

        switch result {
        case .mod(let modId, let fileId, let key, let expires):
            logStore.log("Downloading from NXM: Mod \(modId), File \(fileId)", level: .info)
            let success = await downloadModFromNexus(nexusId: Mod.NexusID(rawValue: modId), fileId: fileId, key: key, expires: expires)
            if success {
                scanMods()
                alertStore.show(localizationStore.L(L10n.VM.nxmDownloadSuccess))
            }
        case .collection(let slug):
            logStore.log("Importing collection from NXM: \(slug)", level: .info)
            NotificationCenter.default.post(name: .switchToTab, object: "ModPacks")
            if let pack = await importCollectionFromURL("https://next.nexusmods.com/stardewvalley/collections/\(slug)") {
                modPacksStore.importedModPack = pack
            } else {
                logStore.log("Import collection returned nil.")
            }
        }
    }

    func selectGameDir() {
        if let url = filePicking.pickDirectory(title: nil) {
            appEnvironment.gameDir = url.path
            refresh()
        }
    }

    func refresh() {
        appEnvironment.checkSmapiVersion()
        scanMods()
        savesStore.reloadSaves()
        appEnvironment.fetchSteamUser()
    }

    // MARK: - Mods

    func scanMods() {
        modsStore.scanMods(gameDir: appEnvironment.gameDir)
    }

    func parseSMAPILog() {
        modsStore.parseSMAPILog(gameDir: appEnvironment.gameDir)
    }

    func toggleMod(_ mod: Mod) {
        modsStore.toggleMod(
            mod,
            gameDir: appEnvironment.gameDir,
            chainToggleDependencies: appEnvironment.chainToggleDependencies,
            log: { [weak self] message in self?.logStore.log(message) },
            onToggled: { [weak self] in self?.profilesStore.syncActiveProfileIds(mods: self?.modsStore.mods ?? []) }
        )
    }

    func setCustomTag(for modId: Mod.UniqueID, tag: String, shouldRefresh: Bool = true) {
        modsStore.setCustomTag(for: modId, tag: tag, shouldRefresh: shouldRefresh, refresh: { [weak self] in self?.refresh() })
    }

    func resetCustomTag(for modId: Mod.UniqueID) {
        modsStore.resetCustomTag(for: modId, refresh: { [weak self] in self?.refresh() })
    }

    func syncTagFromNexus(for mod: Mod, shouldRefresh: Bool = true) async -> Bool {
        await modsStore.syncTagFromNexus(
            for: mod,
            nexusApiKey: appEnvironment.nexusApiKey,
            shouldRefresh: shouldRefresh,
            refresh: { [weak self] in self?.refresh() }
        )
    }

    func syncAllTagsFromNexus() async {
        await modsStore.syncAllTagsFromNexus(nexusApiKey: appEnvironment.nexusApiKey, refresh: { [weak self] in self?.refresh() })
    }

    func openInstallModPanel() async {
        await modsStore.openInstallModPanel(
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    @discardableResult
    func installMod(url: URL) async -> Bool {
        await modsStore.installMod(
            url: url,
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    @discardableResult
    func installModFromZip(url: URL) async -> Bool {
        await modsStore.installModFromZip(
            url: url,
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    @discardableResult
    func installModFromFolder(url: URL) async -> Bool {
        await modsStore.installModFromFolder(
            url: url,
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    func downloadAndInstallUpdate(for mod: ModUpdateInfo, nexusId: Mod.NexusID) async {
        await modsStore.downloadAndInstallUpdate(
            for: mod,
            nexusId: nexusId,
            nexusApiKey: appEnvironment.nexusApiKey,
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    func backupAllMods() {
        modsStore.backupAllMods(gameDir: appEnvironment.gameDir, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func backUp(_ mod: Mod) async {
        await modsStore.backUp(mod, gameDir: appEnvironment.gameDir, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func restore(_ mod: Mod) async {
        await modsStore.restore(mod, gameDir: appEnvironment.gameDir, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func cleanDisabledMods() {
        modsStore.cleanDisabledMods(gameDir: appEnvironment.gameDir, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    // MARK: - SMAPI

    func installSmapi() async {
        await appEnvironment.installSmapi(
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    func uninstallSmapi() async {
        await appEnvironment.uninstallSmapi(
            showModal: { [weak self] message in self?.alertStore.show(message) },
            log: { [weak self] message in self?.logStore.log(message) }
        )
    }

    // MARK: - Saves

    func editSave(info: SaveGameInfo, newName: String, newFarm: String, newFav: String, newMoney: Int, newTotalMoneyEarned: Int, newMaxHealth: Int, newMaxStamina: Int, newGoldenWalnuts: Int, newQiGems: Int, newClubCoins: Int, newSpouse: String) {
        savesStore.editSave(
            info: info, newName: newName, newFarm: newFarm, newFav: newFav, newMoney: newMoney,
            newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newMaxHealth, newMaxStamina: newMaxStamina,
            newGoldenWalnuts: newGoldenWalnuts, newQiGems: newQiGems, newClubCoins: newClubCoins, newSpouse: newSpouse,
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }

    func saveInventory() {
        savesStore.saveInventory(showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func deleteSave(info: SaveGameInfo) {
        savesStore.deleteSave(info: info, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func duplicateSave(info: SaveGameInfo, newName: String, newFarm: String) {
        savesStore.duplicateSave(info: info, newName: newName, newFarm: newFarm, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func branchFromBackup(backup: SaveBackup, newName: String, newFarm: String) {
        savesStore.branchFromBackup(backup: backup, newName: newName, newFarm: newFarm, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func restoreBackup(backup: SaveBackup, info: SaveGameInfo) {
        savesStore.restoreBackup(backup: backup, info: info, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func createBackup(info: SaveGameInfo) {
        savesStore.createBackup(info: info, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func deleteBackup(_ backup: SaveBackup) {
        savesStore.deleteBackup(backup, showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    func backupAllSaves() {
        savesStore.backupAllSaves(showModal: { [weak self] message in self?.alertStore.show(message) })
    }

    // MARK: - Thai Translation Hub

    func fetchThaiTranslations() async {
        await thaiHubStore.fetchThaiTranslations(gameDir: appEnvironment.gameDir, mods: modsStore.mods)
    }

    func evaluateThaiTranslationStatus() {
        thaiHubStore.evaluateThaiTranslationStatus(gameDir: appEnvironment.gameDir, mods: modsStore.mods)
    }

    func installThaiTranslation(_ mod: ThaiTranslationMod) async {
        await thaiHubStore.install(
            mod,
            gameDir: appEnvironment.gameDir,
            showModal: { [weak self] message in self?.alertStore.show(message) },
            onInstalled: { [weak self] in self?.evaluateThaiTranslationStatus() }
        )
    }

    // MARK: - Mod Profiles

    func createProfile(name: String) {
        profilesStore.createProfile(name: name, mods: modsStore.mods)
    }

    func updateProfile(id: UUID, newName: String, enabledModIds: [Mod.UniqueID]) {
        profilesStore.updateProfile(
            id: id,
            newName: newName,
            enabledModIds: enabledModIds,
            gameDir: appEnvironment.gameDir,
            modsProvider: { [weak self] in self?.modsStore.mods ?? [] },
            scanMods: { [weak self] in self?.scanMods() }
        )
    }

    func applyProfile(id: UUID?) {
        profilesStore.applyProfile(
            id: id,
            gameDir: appEnvironment.gameDir,
            modsProvider: { [weak self] in self?.modsStore.mods ?? [] },
            scanMods: { [weak self] in self?.scanMods() },
            log: { [weak self] message in self?.logStore.log(message) },
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }

    func applyChainToSet(mod: Mod, enable: Bool, currentEnabled: Set<Mod.UniqueID>) -> Set<Mod.UniqueID> {
        profilesStore.applyChainToSet(mod: mod, enable: enable, currentEnabled: currentEnabled, mods: modsStore.mods, chainToggleDependencies: appEnvironment.chainToggleDependencies)
    }

    func syncActiveProfileIds() {
        profilesStore.syncActiveProfileIds(mods: modsStore.mods)
    }

    // MARK: - Mod Pack Sharing

    func exportModPack(name: String) -> URL? {
        modPacksStore.exportModPack(
            name: name,
            mods: modsStore.mods,
            steamUsername: appEnvironment.steamUsername,
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }

    func importCollectionFromURL(_ urlString: String) async -> StarHubPack? {
        await modPacksStore.importCollectionFromURL(
            urlString,
            nexusApiKey: appEnvironment.nexusApiKey,
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }

    func downloadModFromNexus(nexusId: Mod.NexusID, fileId: Int? = nil, key: String? = nil, expires: String? = nil) async -> Bool {
        await modPacksStore.downloadModFromNexus(
            nexusId: nexusId,
            fileId: fileId,
            key: key,
            expires: expires,
            nexusApiKey: appEnvironment.nexusApiKey,
            installModFromZip: { [weak self] url, completion in
                Task {
                    let success = await self?.installModFromZip(url: url) ?? false
                    completion(success)
                }
            },
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }

    func downloadAllMissingPackMods(_ pack: StarHubPack) async -> (installed: Int, failed: Int) {
        await modPacksStore.downloadAllMissing(
            from: pack.mods,
            currentMods: modsStore.mods,
            nexusApiKey: appEnvironment.nexusApiKey,
            installModFromZip: { [weak self] url, completion in
                Task {
                    let success = await self?.installModFromZip(url: url) ?? false
                    completion(success)
                }
            },
            showModal: { [weak self] message in self?.alertStore.show(message) }
        )
    }
}

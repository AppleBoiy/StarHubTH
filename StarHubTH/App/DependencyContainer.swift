import Foundation

/// Composition root — the only place in the app allowed to reach for a `.shared`
/// singleton or construct a `Live*` service directly. Phase 4 stores receive their
/// dependencies from here at init instead of reaching for `.shared` themselves.
///
/// Every parameter defaults to the real `Live` implementation, so production code just
/// does `DependencyContainer()`; tests override individual dependencies with a `Stub*`
/// via the initializer.
final class DependencyContainer {
    let nexusAPIClient: NexusAPIClient
    let modScanning: ModScanning
    let modInstalling: ModInstalling
    let saveStoring: SaveStoring
    let saveNoteStoring: SaveNoteStoring
    let profileStoring: ProfileStoring
    let smapiInstalling: SmapiInstalling
    let filePicking: FilePicking
    let preferenceStoring: PreferenceStoring

    init(
        nexusAPIClient: NexusAPIClient = LiveNexusAPIClient.shared,
        modScanning: ModScanning = ModScanner(),
        modInstalling: ModInstalling = ModInstaller(),
        saveStoring: SaveStoring = SaveManager.shared,
        saveNoteStoring: SaveNoteStoring = SaveNotesStore.shared,
        profileStoring: ProfileStoring = ProfileManager.shared,
        smapiInstalling: SmapiInstalling = SmapiInstaller(),
        filePicking: FilePicking = FilePicker(),
        preferenceStoring: PreferenceStoring = PreferenceStore()
    ) {
        self.nexusAPIClient = nexusAPIClient
        self.modScanning = modScanning
        self.modInstalling = modInstalling
        self.saveStoring = saveStoring
        self.saveNoteStoring = saveNoteStoring
        self.profileStoring = profileStoring
        self.smapiInstalling = smapiInstalling
        self.filePicking = filePicking
        self.preferenceStoring = preferenceStoring
    }
}

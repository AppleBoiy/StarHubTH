import Foundation

/// Composition root — the only place in the app allowed to reach for a `.shared`
/// singleton or construct a `Live*` service directly. Phase 4 stores receive their
/// dependencies from here at init instead of reaching for `.shared` themselves.
///
/// Every parameter defaults to the real `Live` implementation, so production code just
/// does `DependencyContainer()`; tests override individual dependencies with a `Stub*`
/// via the initializer. `@MainActor` because its only caller is `MainView`'s own `init()`,
/// and its default values now include main-actor-isolated types (`SmapiInstaller()`).
@MainActor
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
        saveNoteStoring: SaveNoteStoring? = nil,
        profileStoring: ProfileStoring = ProfileManager.shared,
        smapiInstalling: SmapiInstalling? = nil,
        filePicking: FilePicking? = nil,
        preferenceStoring: PreferenceStoring = PreferenceStore()
    ) {
        self.nexusAPIClient = nexusAPIClient
        self.modScanning = modScanning
        self.modInstalling = modInstalling
        self.saveStoring = saveStoring
        // `SaveNotesStore.shared`, `SmapiInstaller()`, and `FilePicker()` are all main-actor
        // isolated, so none of them can be a default argument value (that expression
        // evaluates in a nonisolated context regardless of this init's own isolation) —
        // constructed here in the init body instead, which is main-actor-isolated since the
        // whole type is.
        self.saveNoteStoring = saveNoteStoring ?? SaveNotesStore.shared
        self.profileStoring = profileStoring
        self.smapiInstalling = smapiInstalling ?? SmapiInstaller()
        self.filePicking = filePicking ?? FilePicker()
        self.preferenceStoring = preferenceStoring
    }
}

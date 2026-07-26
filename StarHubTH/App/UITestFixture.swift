import Foundation
import UniformTypeIdentifiers

/// Composition-root override active only when `STARHUB_UITEST_GAME_DIR` is present in the
/// launched process's environment — set by `StarHubTHUITests`' `AppLauncher`, never by a
/// real user launch (`ProcessInfo.processInfo.environment` is empty of it otherwise). Lets a
/// UI test point the app at an isolated temp `gameDir`/preferences suite and skip
/// `NSOpenPanel` (which XCUITest cannot drive) without changing any production code path a
/// real user takes.
struct UITestFixture {
    private static let preferencesSuiteName = "com.appleboiy.StarHubTH.uitest"

    static var current: UITestFixture? {
        guard let gameDir = ProcessInfo.processInfo.environment["STARHUB_UITEST_GAME_DIR"] else { return nil }
        return UITestFixture(gameDir: gameDir)
    }

    let gameDir: String

    /// A fixed, non-`.standard` `UserDefaults` suite, reset at the start of every launch —
    /// so consecutive UI test runs never see state left over from a previous one, without
    /// needing per-process cleanup.
    ///
    /// When `STARHUB_UITEST_USE_REAL_API_KEY=1` is also set (Tier C "live" UI tests only —
    /// see `TestPlans/UILive.xctestplan`), seeds the isolated suite with the real Nexus API
    /// key from `UserDefaults.standard` — the same domain the app's own Settings screen
    /// writes to, since this code runs inside the launched `StarHubTH.app` process itself,
    /// not the test host (contrast `Tests/Integration/LiveTestGate.swift`, which needs
    /// `.standard` for the opposite reason: avoiding a `suiteName:` that collides with the
    /// *test host's* own bundle ID).
    @MainActor
    var preferenceStoring: PreferenceStoring {
        let defaults = UserDefaults(suiteName: Self.preferencesSuiteName) ?? .standard
        defaults.removePersistentDomain(forName: Self.preferencesSuiteName)
        defaults.set(gameDir, forKey: "gameDir")
        if ProcessInfo.processInfo.environment["STARHUB_UITEST_USE_REAL_API_KEY"] == "1" {
            let realApiKey = UserDefaults.standard.string(forKey: "nexusApiKey") ?? ""
            defaults.set(realApiKey, forKey: "nexusApiKey")
        }
        return PreferenceStore(defaults: defaults)
    }

    /// Substitutes a fixed URL for `NSOpenPanel` when `STARHUB_UITEST_FIXTURE_MOD_PATH` is
    /// also set, so a UI test can drive the real install pipeline past the one step XCUITest
    /// can't automate. Falls back to the real picker otherwise.
    @MainActor
    var filePicking: FilePicking {
        guard let fixturePath = ProcessInfo.processInfo.environment["STARHUB_UITEST_FIXTURE_MOD_PATH"] else {
            return FilePicker()
        }
        return FixedURLFilePicker(fixedURL: URL(fileURLWithPath: fixturePath))
    }
}

@MainActor
private struct FixedURLFilePicker: FilePicking {
    let fixedURL: URL

    func pickDirectory(title: String?) -> URL? { fixedURL }
    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] { [fixedURL] }
    func pickSaveLocation(title: String?, suggestedName: String, allowedContentTypes: [UTType]) -> URL? { fixedURL }
    func reveal(_ url: URL) {}
}

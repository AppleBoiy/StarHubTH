import Foundation

/// Characterization tests for AppEnvironment, extracted from StarHubTHViewModel in
/// refactor Phase 4.8. fetchSteamUser() reads a hardcoded real VDF file path with no
/// injection seam, same reasoning as every other untested I/O path so far — not
/// covered here.
@MainActor
struct AppEnvironmentTests {
    static func run() {
        print("Running AppEnvironmentTests...")
        testUsesSavedGameDirWhenPathExists()
        testFallsBackToDetectedDirWhenSavedPathMissing()
        testGameDirChangePersists()
        testCheckSmapiVersionClearsWhenGameDirEmpty()
    }

    private static func testUsesSavedGameDirWhenPathExists() {
        let realDir = FileManager.default.temporaryDirectory.path
        let prefs = StubPreferenceStoring()
        prefs.set(realDir, forKey: "gameDir")

        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))
        SimpleTestFramework.assertEqual(env.gameDir, realDir, "a saved gameDir that still exists on disk is used as-is")
    }

    private static func testFallsBackToDetectedDirWhenSavedPathMissing() {
        let prefs = StubPreferenceStoring()
        prefs.set("/this/path/does/not/exist", forKey: "gameDir")

        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))
        SimpleTestFramework.assertEqual(env.gameDir, AppEnvironment.detectDefaultGameDir(), "a saved gameDir that no longer exists falls back to the detected default")
    }

    private static func testGameDirChangePersists() {
        let prefs = StubPreferenceStoring()
        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))

        env.gameDir = "/a/new/path"
        SimpleTestFramework.assertEqual(prefs.string(forKey: "gameDir"), "/a/new/path", "setting gameDir persists it via PreferenceStoring")
    }

    private static func testCheckSmapiVersionClearsWhenGameDirEmpty() {
        let prefs = StubPreferenceStoring()
        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))

        env.gameDir = ""
        env.smapiInstalledVersion = "1.0.0"
        env.checkSmapiVersion()
        SimpleTestFramework.assertTrue(env.smapiInstalledVersion == nil, "checkSmapiVersion clears the version when gameDir is empty")
    }
}

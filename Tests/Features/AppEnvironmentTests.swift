import XCTest
@testable import StarHubTH

/// Characterization tests for AppEnvironment, extracted from StarHubTHViewModel in
/// refactor Phase 4.8. fetchSteamUser() reads a hardcoded real VDF file path with no
/// injection seam, same reasoning as every other untested I/O path so far — not
/// covered here.
@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testUsesSavedGameDirWhenPathExists() {
        let realDir = FileManager.default.temporaryDirectory.path
        let prefs = StubPreferenceStoring()
        prefs.set(realDir, forKey: "gameDir")

        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))
        XCTAssertEqual(env.gameDir, realDir, "a saved gameDir that still exists on disk is used as-is")
    }

    func testFallsBackToDetectedDirWhenSavedPathMissing() {
        let prefs = StubPreferenceStoring()
        prefs.set("/this/path/does/not/exist", forKey: "gameDir")

        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))
        XCTAssertEqual(env.gameDir, AppEnvironment.detectDefaultGameDir(), "a saved gameDir that no longer exists falls back to the detected default")
    }

    func testGameDirChangePersists() {
        let prefs = StubPreferenceStoring()
        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))

        env.gameDir = "/a/new/path"
        XCTAssertEqual(prefs.string(forKey: "gameDir"), "/a/new/path", "setting gameDir persists it via PreferenceStoring")
    }

    func testCheckSmapiVersionClearsWhenGameDirEmpty() {
        let prefs = StubPreferenceStoring()
        let env = AppEnvironment(preferenceStoring: prefs, localization: LocalizationStore(preferenceStoring: StubPreferenceStoring()))

        env.gameDir = ""
        env.smapiInstalledVersion = "1.0.0"
        env.checkSmapiVersion()
        XCTAssertTrue(env.smapiInstalledVersion == nil, "checkSmapiVersion clears the version when gameDir is empty")
    }
}

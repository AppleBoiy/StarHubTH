import Foundation

/// Builds isolated on-disk fixtures for round-trip UI tests — a temp `gameDir` the app is
/// pointed at via `STARHUB_UITEST_GAME_DIR` (`StarHubTH/App/UITestFixture.swift`), so tests
/// never touch a real Stardew Valley install or the shared SMAPI log.
enum UITestEnvironment {
    struct Workspace {
        let gameDir: URL
        /// The mod root `STARHUB_UITEST_FIXTURE_MOD_PATH` points at — what `install-mod-button`
        /// "picks" instead of presenting `NSOpenPanel`. Lives outside `gameDir` so the install
        /// test starts from an empty `Mods/` folder, same as a fresh game install would.
        let fixtureModRoot: URL
        let smapiLogPath: URL

        var launchEnvironment: [String: String] {
            [
                "STARHUB_UITEST_GAME_DIR": gameDir.path,
                "STARHUB_UITEST_FIXTURE_MOD_PATH": fixtureModRoot.path,
                "STARHUB_UITEST_SMAPI_LOG_PATH": smapiLogPath.path,
            ]
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: gameDir.deletingLastPathComponent())
        }
    }

    private static let manifestJSON = """
    {
      "Name": "StarHub UITest Fixture Mod",
      "UniqueID": "AppleBoiy.StarHubUITestFixtureMod",
      "Version": "1.0.0",
      "Author": "AppleBoiy",
      "Description": "Installed by StarHubTHUITests for round-trip coverage.",
      "UpdateKeys": []
    }
    """

    private static let configJSON = """
    {
      "EnableFeature": false
    }
    """

    /// Fresh temp directories per call — each test gets its own isolated workspace, no state
    /// bleed between test methods even within the same run.
    ///
    /// - Parameter preInstallFixtureMod: when true, `gameDir/Mods/FixtureMod` (manifest +
    ///   config.json) already exists, for tests that need an installed mod without going
    ///   through the install UI themselves (editing, observing). When false, `gameDir/Mods`
    ///   doesn't exist yet — for the install test itself.
    static func makeWorkspace(preInstallFixtureMod: Bool) -> Workspace {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTHUITests-\(UUID().uuidString)")
        let gameDir = root.appendingPathComponent("GameDir")
        let fixtureModRoot = root.appendingPathComponent("FixtureSource/FixtureMod")
        let smapiLogPath = root.appendingPathComponent("SMAPI-latest.txt")

        try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: fixtureModRoot, withIntermediateDirectories: true)
        try? manifestJSON.write(to: fixtureModRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try? configJSON.write(to: fixtureModRoot.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: smapiLogPath.path, contents: Data())

        if preInstallFixtureMod {
            let installedModRoot = gameDir.appendingPathComponent("Mods/FixtureMod")
            try? FileManager.default.createDirectory(at: installedModRoot, withIntermediateDirectories: true)
            try? manifestJSON.write(to: installedModRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
            try? configJSON.write(to: installedModRoot.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        }

        return Workspace(gameDir: gameDir, fixtureModRoot: fixtureModRoot, smapiLogPath: smapiLogPath)
    }
}

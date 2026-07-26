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
        /// Set only by Tier C ("live") tests — see `TestPlans/UILive.xctestplan` — to seed the
        /// isolated preferences suite with the real Nexus API key already configured in the
        /// app's own Settings (`UITestFixture.preferenceStoring`).
        var useRealApiKey: Bool = false

        var launchEnvironment: [String: String] {
            var environment = [
                "STARHUB_UITEST_GAME_DIR": gameDir.path,
                "STARHUB_UITEST_FIXTURE_MOD_PATH": fixtureModRoot.path,
                "STARHUB_UITEST_SMAPI_LOG_PATH": smapiLogPath.path,
            ]
            if useRealApiKey {
                environment["STARHUB_UITEST_USE_REAL_API_KEY"] = "1"
            }
            return environment
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: gameDir.deletingLastPathComponent())
        }
    }

    /// - Parameter nexusModId: when non-nil, embeds `"nexus:<id>"` in `UpdateKeys` so
    ///   `mod.nexusUrl` resolves to a real Nexus mod page (`ModManifestParser`) — needed for
    ///   Tier C tests that load real Nexus data for the fixture mod. `nil` (the default)
    ///   keeps the manifest Nexus-less, as every non-live UI test expects.
    private static func manifestJSON(nexusModId: Int?) -> String {
        let updateKeys = nexusModId.map { "\"nexus:\($0)\"" } ?? ""
        return """
        {
          "Name": "StarHub UITest Fixture Mod",
          "UniqueID": "AppleBoiy.StarHubUITestFixtureMod",
          "Version": "1.0.0",
          "Author": "AppleBoiy",
          "Description": "Installed by StarHubTHUITests for round-trip coverage.",
          "UpdateKeys": [\(updateKeys)]
        }
        """
    }

    private static let configJSON = """
    {
      "EnableFeature": false
    }
    """

    /// Fresh temp directories per call — each test gets its own isolated workspace, no state
    /// bleed between test methods even within the same run.
    ///
    /// - Parameters:
    ///   - preInstallFixtureMod: when true, `gameDir/Mods/FixtureMod` (manifest +
    ///     config.json) already exists, for tests that need an installed mod without going
    ///     through the install UI themselves (editing, observing). When false, `gameDir/Mods`
    ///     doesn't exist yet — for the install test itself.
    ///   - nexusModId: see `manifestJSON(nexusModId:)` — Tier C only.
    ///   - useRealApiKey: see `Workspace.useRealApiKey` — Tier C only.
    static func makeWorkspace(preInstallFixtureMod: Bool, nexusModId: Int? = nil, useRealApiKey: Bool = false) -> Workspace {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTHUITests-\(UUID().uuidString)")
        let gameDir = root.appendingPathComponent("GameDir")
        let fixtureModRoot = root.appendingPathComponent("FixtureSource/FixtureMod")
        let smapiLogPath = root.appendingPathComponent("SMAPI-latest.txt")
        let manifest = manifestJSON(nexusModId: nexusModId)

        try? FileManager.default.createDirectory(at: gameDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: fixtureModRoot, withIntermediateDirectories: true)
        try? manifest.write(to: fixtureModRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
        try? configJSON.write(to: fixtureModRoot.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        FileManager.default.createFile(atPath: smapiLogPath.path, contents: Data())

        if preInstallFixtureMod {
            let installedModRoot = gameDir.appendingPathComponent("Mods/FixtureMod")
            try? FileManager.default.createDirectory(at: installedModRoot, withIntermediateDirectories: true)
            try? manifest.write(to: installedModRoot.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
            try? configJSON.write(to: installedModRoot.appendingPathComponent("config.json"), atomically: true, encoding: .utf8)
        }

        return Workspace(gameDir: gameDir, fixtureModRoot: fixtureModRoot, smapiLogPath: smapiLogPath, useRealApiKey: useRealApiKey)
    }
}

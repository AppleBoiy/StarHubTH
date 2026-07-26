import Foundation

/// Shared skip gate for `Tests/Integration/` — these tests make real network calls
/// (Nexus Mods API, GitHub's public releases API), unlike everything else in the suite.
/// Set `STARHUB_SKIP_LIVE_TESTS=1` to skip all of them — CI does this by default, since
/// network flakiness or a GitHub rate limit shouldn't fail an unrelated build.
enum LiveTestGate {
    static var isSkipped: Bool {
        ProcessInfo.processInfo.environment["STARHUB_SKIP_LIVE_TESTS"] == "1"
    }

    /// The real Nexus API key, if one is configured — read the same way the app itself
    /// does (`AppEnvironment.nexusApiKey`/`SettingsView`'s `@AppStorage`), so entering a key
    /// once in the app's own Settings screen is all that's needed for these tests too.
    ///
    /// Deliberately `UserDefaults.standard`, not `UserDefaults(suiteName: "com.appleboiy.StarHubTH")`
    /// — the latter returns `nil` when the suite name matches the *calling* process's own
    /// bundle ID (which it does here, since `StarHubTHTests` hosts inside the `StarHubTH.app`
    /// bundle), a real macOS `UserDefaults` quirk. Every Integration test that read via
    /// `suiteName:` silently skipped on every run as a result — `.standard` is what actually
    /// resolves to the same domain in this hosted-test setup.
    static var nexusApiKey: String {
        UserDefaults.standard.string(forKey: "nexusApiKey") ?? ""
    }

    /// A second, separate gate for tests that don't just read from Nexus but mutate a real
    /// account (`endorseMod`) — deliberately **not** folded into `isSkipped`. A developer who
    /// enables `STARHUB_SKIP_LIVE_TESTS=0` to run the normal Integration suite should not
    /// also, silently, endorse a real mod on whichever account owns the configured API key.
    /// This must be set explicitly, every time, to run anything gated by it.
    static var isMutatingTestsSkipped: Bool {
        ProcessInfo.processInfo.environment["STARHUB_RUN_MUTATING_NEXUS_TESTS"] != "1"
    }
}

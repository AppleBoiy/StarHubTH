import Foundation

/// Shared skip gate for `Tests/Integration/` — these tests make real network calls
/// (Nexus Mods API, GitHub's public releases API), unlike everything else in the suite.
/// Set `STARHUB_SKIP_LIVE_TESTS=1` to skip all of them — CI does this by default, since
/// network flakiness or a GitHub rate limit shouldn't fail an unrelated build.
enum LiveTestGate {
    static var isSkipped: Bool {
        ProcessInfo.processInfo.environment["STARHUB_SKIP_LIVE_TESTS"] == "1"
    }

    /// Returns true (and prints/records a skip) if the caller should return early.
    static func skipIfNeeded(_ testName: String) -> Bool {
        guard isSkipped else { return false }
        print("⚠️ SKIPPING \(testName): STARHUB_SKIP_LIVE_TESTS=1")
        SimpleTestFramework.assertTrue(true, "Skipped due to STARHUB_SKIP_LIVE_TESTS")
        return true
    }
}

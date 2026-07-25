import Foundation

/// Characterization test for LogStore, extracted from StarHubTHViewModel in refactor
/// Phase 4.2. loadSmapiLog() isn't covered here — it reads a hardcoded real filesystem
/// path with no injection seam, same as the original; log() needs no stubbing since its
/// only side effect besides the two @Published properties is a fire-and-forget debug
/// log write.
struct LogStoreTests {
    static func run() {
        print("Running LogStoreTests...")
        testLogAppendsEntry()
    }

    private static func testLogAppendsEntry() {
        let store = LogStore()
        store.log("Test message", level: .warning)
        SimpleTestFramework.assertEqual(store.logEntries.count, 1, "log() appends one entry")
        SimpleTestFramework.assertEqual(store.logEntries.first?.message, "Test message", "the entry carries the logged message")
        SimpleTestFramework.assertEqual(store.logEntries.first?.level, .warning, "the entry carries the specified level")
        SimpleTestFramework.assertTrue(store.logOutput.contains("Test message"), "logOutput accumulates the formatted line")
    }
}

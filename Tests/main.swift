import Foundation

print("Starting StarHubTH Test Suite...\n")

ModTagInferenceTests.run()
ModGraphTests.run()
ModListFilterTests.run()
LocalizationStoreTests.run()
LogStoreTests.run()
ProfilesStoreTests.run()
SavesStoreTests.run()
AppEnvironmentTests.run()
ModManifestParserTests.run()
SaveFileParserTests.run()
SaveManagerTests.run()
SmapiLogParserTests.run()
SmapiInstallerTests.run()

// Every suite below either awaits real async work or still ends in a
// DispatchQueue.main.async-wrapped completion (ModInstaller.installFromZip hasn't been
// converted yet — that's Phase 5.2's install cluster). All of them run the same way: on a
// background thread via Task.detached, while this (real) main thread pumps its RunLoop so
// any DispatchQueue.main.async hop still has somewhere to land. Mixing plain top-level
// `await` in here with this manual pumping starves the pump at unpredictable points — every
// suite goes through the identical pattern so there's one thread model, not two.
func runSuite(deadline seconds: TimeInterval, _ body: @escaping () async -> Void) {
    let done = DispatchSemaphore(value: 0)
    Task.detached {
        await body()
        done.signal()
    }
    let cutoff = Date().addingTimeInterval(seconds)
    while done.wait(timeout: .now()) == .timedOut && Date() < cutoff {
        RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }
}

runSuite(deadline: 120) { await NXMParserTests.run() }
runSuite(deadline: 30) { await NexusCollectionTests.run() }
runSuite(deadline: 120) { await ModUpdateTests.run() }
runSuite(deadline: 5) { await ModPacksStoreTests.run() }
runSuite(deadline: 10) { ModsStoreTests.run() }

SimpleTestFramework.report()

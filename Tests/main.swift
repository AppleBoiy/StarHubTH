import Foundation

print("Starting StarHubTH Test Suite...\n")

ModTagInferenceTests.run()
ModGraphTests.run()
ModListFilterTests.run()
LocalizationStoreTests.run()
LogStoreTests.run()
ProfilesStoreTests.run()
SavesStoreTests.run()
ModManifestParserTests.run()
SaveFileParserTests.run()
SmapiLogParserTests.run()
SmapiInstallerTests.run()

// NXMParserTests includes a live integration test that uses URLSession + DispatchQueue.main.
// We run it on a background thread and pump the main RunLoop so those async dispatches can fire.
let nxmDone = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .userInitiated).async {
    NXMParserTests.run()
    nxmDone.signal()
}
// Spin the main RunLoop (which drains DispatchQueue.main) until the background test finishes.
let nxmDeadline = Date().addingTimeInterval(120)
while nxmDone.wait(timeout: .now()) == .timedOut && Date() < nxmDeadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}

// NexusCollectionTests: also async (GraphQL) — same pattern
let collectionDone = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .userInitiated).async {
    NexusCollectionTests.run()
    collectionDone.signal()
}
let collectionDeadline = Date().addingTimeInterval(30)
while collectionDone.wait(timeout: .now()) == .timedOut && Date() < collectionDeadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}

// ModUpdateTests: async auto-update flow
let updateDone = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .userInitiated).async {
    ModUpdateTests.run()
    updateDone.signal()
}
let updateDeadline = Date().addingTimeInterval(120)
while updateDone.wait(timeout: .now()) == .timedOut && Date() < updateDeadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}

// ModPacksStoreTests: its stub still goes through the store's real DispatchQueue.main.async
// hop, so it needs the same RunLoop-pumping pattern even though nothing here touches a
// real network.
let modPacksDone = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .userInitiated).async {
    ModPacksStoreTests.run()
    modPacksDone.signal()
}
let modPacksDeadline = Date().addingTimeInterval(5)
while modPacksDone.wait(timeout: .now()) == .timedOut && Date() < modPacksDeadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}

// ModsStoreTests: several tests call drainMainQueue() (a local semaphore wait) to let
// DispatchQueue.main.async-wrapped state updates (scanMods, installModFromZip) finish
// before asserting — that wait would deadlock on the main thread, same reasoning as
// ModPacksStoreTests above.
let modsStoreDone = DispatchSemaphore(value: 0)
DispatchQueue.global(qos: .userInitiated).async {
    ModsStoreTests.run()
    modsStoreDone.signal()
}
let modsStoreDeadline = Date().addingTimeInterval(10)
while modsStoreDone.wait(timeout: .now()) == .timedOut && Date() < modsStoreDeadline {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
}

SimpleTestFramework.report()

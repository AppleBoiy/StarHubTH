import XCTest
@testable import StarHubTH

final class NexusCollectionTests: XCTestCase {
    func testFetchCollectionWithRealData() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")

        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        let slug = "tckf0m"

        do {
            let collection = try await LiveNexusAPIClient.shared.collectionGraph(slug: slug, apiKey: apiKey)
            XCTAssertEqual(collection.slug, slug, "Slug should match")
            XCTAssertEqual(collection.game?.domainName, "stardewvalley", "Game domain should be stardewvalley")
            XCTAssertTrue(collection.latestPublishedRevision != nil, "Should have a latest revision")

            if let modFiles = collection.latestPublishedRevision?.modFiles {
                XCTAssertTrue(modFiles.count > 0, "Collection should contain mods")
                if let firstMod = modFiles.first?.file?.mod {
                    XCTAssertTrue(firstMod.modId > 0, "Mods should have a valid modId")
                }
            } else {
                XCTAssertTrue(false, "Collection modFiles were nil")
            }
        } catch {
            print("DECODING ERROR DETAILED: \(error)")
            XCTAssertTrue(false, "Failed to fetch actual collection data: \(error.localizedDescription)")
        }
    }
}

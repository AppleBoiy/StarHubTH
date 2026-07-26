import XCTest
@testable import StarHubTH

/// Live integration test: `LiveNexusAPIClient.modInfo` had zero coverage against the real
/// API before this — every other Integration test exercises `modFiles`/`downloadLink`/
/// `collectionGraph`, never this one. Read-only, no account mutation.
final class ModInfoIntegrationTests: XCTestCase {
    func testFetchModInfoWithRealData() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")

        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        // Same mod every other Integration test targets: "Mail Framework Mod" (Nexus ID 1536).
        let modId = 1536

        let info = try await LiveNexusAPIClient.shared.modInfo(modId: modId, apiKey: apiKey)
        XCTAssertFalse(info.name.isEmpty, "A real mod should have a non-empty name")
        XCTAssertFalse(info.description.isEmpty, "A real mod should have a non-empty description")
        XCTAssertNotNil(info.categoryId, "A real mod should have a category")
    }
}

import XCTest
@testable import StarHubTH

/// ⚠️ **This test mutates a real Nexus account.** `endorseMod` posts a real, externally
/// visible endorsement to whichever account owns the configured API key — it is not
/// read-only like every other Integration test, and running it repeatedly doesn't "reset."
///
/// It therefore has its own gate, `STARHUB_RUN_MUTATING_NEXUS_TESTS=1`
/// (`LiveTestGate.isMutatingTestsSkipped`), separate from and in addition to
/// `STARHUB_SKIP_LIVE_TESTS` — the normal live-test flag is not enough to run this, on
/// purpose. Do not enable it unless you specifically intend to endorse "Mail Framework Mod"
/// (Nexus ID 1536) on the account tied to your configured key. See
/// docs/LIVE_NEXUS_WORKFLOW_TEST_PLAN.md ("Tier B") for the full reasoning.
final class NexusEndorseIntegrationTests: XCTestCase {
    func testEndorseModAgainstRealAccount() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")
        try XCTSkipIf(LiveTestGate.isMutatingTestsSkipped, "STARHUB_RUN_MUTATING_NEXUS_TESTS not set to 1 — this test mutates a real Nexus account and does not run by default, even when live tests are otherwise enabled.")
        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        try await LiveNexusAPIClient.shared.endorseMod(modId: 1536, version: nil, apiKey: apiKey)
        // No assertion beyond "didn't throw" — endorseMod's success response carries no
        // state worth asserting on beyond that, and re-querying mod info wouldn't reliably
        // reflect the endorsement immediately.
    }
}

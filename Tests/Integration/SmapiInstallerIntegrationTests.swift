import XCTest
@testable import StarHubTH

/// Live integration test: real, unauthenticated call to api.github.com. Unlike the Nexus
/// integration tests, there's no API key to gate on — this one only had the
/// STARHUB_SKIP_LIVE_TESTS gate to rely on, and used to have neither (see docs/QOC_PLAN.md
/// Phase A) — it ran unconditionally, including in CI, with no way to skip it.
final class SmapiInstallerIntegrationTests: XCTestCase {
    func testResolveLatestSmapiInstallerURL() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")

        do {
            let (url, version) = try await SmapiInstaller.resolveLatestSmapiInstallerURL()
            XCTAssertTrue(url.absoluteString.contains("SMAPI-"), "URL should contain SMAPI-")
            XCTAssertTrue(url.absoluteString.contains("-installer.zip"), "URL should contain -installer.zip")
            XCTAssertFalse(url.absoluteString.contains("double-zipped"), "URL should NOT contain double-zipped")
            XCTAssertTrue(version.count > 0, "Version should not be empty")
        } catch {
            XCTAssertTrue(false, "API resolution failed: \(error.messageKey) - \(error.detail ?? "")")
        }
    }
}

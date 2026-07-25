import Foundation

/// Live integration test: real, unauthenticated call to api.github.com. Unlike the Nexus
/// integration tests, there's no API key to gate on — this one only had the
/// STARHUB_SKIP_LIVE_TESTS gate to rely on, and used to have neither (see docs/QOC_PLAN.md
/// Phase A) — it ran unconditionally, including in CI, with no way to skip it.
class SmapiInstallerIntegrationTests {
    static func run() async {
        print("Running SmapiInstallerIntegrationTests...")
        await testResolveLatestSmapiInstallerURL()
    }

    static func testResolveLatestSmapiInstallerURL() async {
        guard !LiveTestGate.skipIfNeeded("testResolveLatestSmapiInstallerURL") else { return }

        do {
            let (url, version) = try await SmapiInstaller.resolveLatestSmapiInstallerURL()
            SimpleTestFramework.assertTrue(url.absoluteString.contains("SMAPI-"), "URL should contain SMAPI-")
            SimpleTestFramework.assertTrue(url.absoluteString.contains("-installer.zip"), "URL should contain -installer.zip")
            SimpleTestFramework.assertFalse(url.absoluteString.contains("double-zipped"), "URL should NOT contain double-zipped")
            SimpleTestFramework.assertTrue(version.count > 0, "Version should not be empty")
        } catch {
            SimpleTestFramework.assertTrue(false, "API resolution failed: \(error.messageKey) - \(error.detail ?? "")")
        }
    }
}

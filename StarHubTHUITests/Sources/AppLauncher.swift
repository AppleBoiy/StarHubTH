import XCTest

/// Launches the app under test. Once folded into the unified Xcode project (Xcode
/// Migration Plan, Phase 2), the `StarHubTHUITests` target's `TEST_TARGET_NAME` build
/// setting points Xcode at the `StarHubTH` app target directly, so a bare
/// `XCUIApplication()` resolves to it — no more launching an externally-built `.app` by
/// path, which the pre-migration spike needed since Xcode didn't build the app itself.
enum AppLauncher {
    static func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }
}

import Foundation

/// Skip gate for the small number of Tier C UI tests that need a real Nexus API key —
/// see `TestPlans/UILive.xctestplan`. Reads via `UserDefaults(suiteName: "com.appleboiy.StarHubTH")`
/// **from the UI test runner process**, which is safe here even though the identical pattern
/// is broken for `Tests/Integration/LiveTestGate.swift`: that bundle hosts inside `StarHubTH.app`
/// itself (same bundle ID, so `suiteName:` collides with the calling process and returns `nil`),
/// while `StarHubTHUITests` runs as its own separate XCUITest-Runner process with a distinct
/// bundle ID — no collision, `suiteName:` resolves correctly.
enum LiveUITestGate {
    static var nexusApiKey: String {
        UserDefaults(suiteName: "com.appleboiy.StarHubTH")?.string(forKey: "nexusApiKey") ?? ""
    }
}

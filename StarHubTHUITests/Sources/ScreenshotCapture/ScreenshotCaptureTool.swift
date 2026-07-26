import XCTest

/// Drives the REAL, already-configured `StarHubTH.app` — not the isolated `UITestFixture`
/// seam every other `StarHubTHUITests` suite uses — to capture release screenshots against
/// the maintainer's own real `gameDir`/mods/saves/profiles/Nexus data. `XCUIApplication().launch()`
/// with no `STARHUB_UITEST_*` environment set means `UITestFixture.current` returns nil
/// (`StarHubTH/App/UITestFixture.swift`), so the app boots exactly as it would for a real user:
/// real `UserDefaults.standard`, real `gameDir`, real Nexus API key.
///
/// Never wired into `Fast`/`Unit`/`Integration`/`UI`/`UILive` — only runs via its own
/// `TestPlans/ScreenshotCapture.xctestplan`, and even then only fires with
/// `STARHUB_SCREENSHOT_OUTPUT_DIR` explicitly set, so it can never trigger by accident.
/// See `docs/RELEASING.md`'s screenshot-refresh step and `scripts/screenshot_manifest.json`.
@MainActor
final class ScreenshotCaptureTool: XCTestCase {
    func testCaptureCoreScreens() throws {
        guard let outputDir = ProcessInfo.processInfo.environment["STARHUB_SCREENSHOT_OUTPUT_DIR"] else {
            throw XCTSkip("STARHUB_SCREENSHOT_OUTPUT_DIR not set — this tool only runs when explicitly invoked, see docs/RELEASING.md")
        }
        let manifestPath = ProcessInfo.processInfo.environment["STARHUB_SCREENSHOT_MANIFEST_PATH"] ?? "scripts/screenshot_manifest.json"
        let targetsPath = ProcessInfo.processInfo.environment["STARHUB_SCREENSHOT_TARGETS_PATH"]

        let manifest = try Self.loadManifest(at: manifestPath)
        let targets = try targetsPath.map { try Self.loadTargets(at: $0) } ?? [:]
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let coreScreens = manifest.screens.filter { $0.tier == "core" }
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        var failures: [String] = []
        for entry in coreScreens {
            do {
                try Self.navigate(app: app, steps: entry.navigation, targets: targets)
                // Navigation's last click can return before SwiftUI finishes animating the
                // resulting transition — a fixed settle delay, not another waitForExistence,
                // since what changed varies per screen and there's no one element to wait on.
                Thread.sleep(forTimeInterval: 0.5)
                try Self.capture(app: app, id: entry.id, outputDir: outputDir)
            } catch {
                failures.append("\(entry.id): \(error)")
            }
            Self.returnToBaseline(app: app)
        }

        if !failures.isEmpty {
            print("[ScreenshotCaptureTool] \(failures.count)/\(coreScreens.count) screen(s) failed to capture:")
            for failure in failures { print("  - \(failure)") }
        }
        XCTAssertLessThan(failures.count, coreScreens.count, "every Core screen failed to capture — check STARHUB_SCREENSHOT_TARGETS_PATH and app state")
    }

    private static func loadManifest(at path: String) throws -> ScreenshotManifest {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(ScreenshotManifest.self, from: data)
    }

    private static func loadTargets(at path: String) throws -> [String: String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    private static func resolve(_ identifier: String, targets: [String: String]) throws -> String {
        var resolved = identifier
        for (key, value) in targets {
            resolved = resolved.replacingOccurrences(of: "<\(key)>", with: value)
        }
        guard !resolved.contains("<") else {
            throw CaptureError.unresolvedPlaceholder(identifier)
        }
        return resolved
    }

    private static func element(app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    /// Every click in this file goes through here — `XCUIElement.click()` has no `throws`
    /// marker, so calling it on an element that doesn't exist raises a hard, uncatchable
    /// XCTest failure instead of something a Swift `do`/`catch` can intercept, aborting the
    /// whole test rather than just failing the one screen being captured. Always checking
    /// `waitForExistence` first and throwing our own `CaptureError` keeps failures scoped to
    /// a single manifest entry.
    private static func guardedClick(_ target: XCUIElement, description: String, timeout: TimeInterval = 10) throws {
        guard target.waitForExistence(timeout: timeout) else { throw CaptureError.elementNotFound(description) }
        target.click()
    }

    private static func navigate(app: XCUIApplication, steps: [NavigationStep], targets: [String: String]) throws {
        for step in steps {
            switch step.action {
            case "click":
                let resolved = try resolve(step.identifier ?? "", targets: targets)
                try guardedClick(element(app: app, identifier: resolved), description: resolved)

            case "clickDescendant":
                guard let rowIdentifier = step.rowIdentifier, let descendantLabel = step.descendantLabel else { continue }
                let row = try resolve(rowIdentifier, targets: targets)
                let target = app.descendants(matching: .any).matching(
                    NSPredicate(format: "identifier == %@ AND label == %@", row, descendantLabel)
                ).firstMatch
                try guardedClick(target, description: row)

            case "clickMenuItem":
                guard let menuIdentifier = step.menuIdentifier, let index = step.index else { continue }
                let resolved = try resolve(menuIdentifier, targets: targets)
                try guardedClick(element(app: app, identifier: resolved), description: resolved)
                try guardedClick(app.menuItems.element(boundBy: index), description: "\(resolved) menu item \(index)", timeout: 5)

            case "clickSegment":
                guard let identifier = step.identifier else { continue }
                let picker = element(app: app, identifier: identifier)
                guard picker.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound(identifier) }
                if let segmentIndex = step.segmentIndex {
                    try guardedClick(picker.buttons.element(boundBy: segmentIndex), description: "\(identifier) segment \(segmentIndex)")
                } else if let segmentLabel = step.segmentLabel {
                    let segment = picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", segmentLabel)).firstMatch
                    try guardedClick(segment, description: "\(identifier) segment '\(segmentLabel)'")
                }

            default:
                break
            }
        }
    }

    private static func capture(app: XCUIApplication, id: String, outputDir: String) throws {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound("app window") }
        let screenshot = window.screenshot()
        let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent("\(id).png")
        try screenshot.pngRepresentation.write(to: outputURL)
    }

    /// Best-effort reset between captures: return to Mods via the sidebar rather than
    /// tracking exact undo steps for every navigation path above — every Core entry's
    /// navigation starts from a sidebar click, so this is enough to avoid one entry's
    /// leftover state (an open detail view, an open menu) bleeding into the next capture.
    ///
    /// Escape first, always: a `.sheet` (e.g. Profile Detail) sits on top of and blocks the
    /// sidebar entirely — clicking `sidebar-tab-Mods` while one is open is silently absorbed
    /// by the sheet, not routed to the sidebar underneath, so navigation for every subsequent
    /// entry quietly no-ops and each one "succeeds" at capturing the exact same frozen sheet.
    /// Discovered by real captures against this machine's own populated app state producing
    /// six byte-identical PNGs in a row after `profile-detail`.
    private static func returnToBaseline(app: XCUIApplication) {
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let modsTab = element(app: app, identifier: "sidebar-tab-Mods")
        if modsTab.exists {
            modsTab.click()
        }
    }
}

private struct ScreenshotManifest: Decodable {
    let screens: [ScreenshotEntry]
}

private struct ScreenshotEntry: Decodable {
    let id: String
    let feature: String
    let description: String
    let tier: String
    let precondition: String?
    let placeholders: [String]?
    let navigation: [NavigationStep]
}

private struct NavigationStep: Decodable {
    let action: String
    let identifier: String?
    let menuIdentifier: String?
    let index: Int?
    let segmentLabel: String?
    let segmentIndex: Int?
    let rowIdentifier: String?
    let descendantLabel: String?
    let note: String?
}

private enum CaptureError: Error, CustomStringConvertible {
    case elementNotFound(String)
    case unresolvedPlaceholder(String)

    var description: String {
        switch self {
        case .elementNotFound(let identifier): return "element not found: \(identifier)"
        case .unresolvedPlaceholder(let identifier): return "unresolved placeholder, check STARHUB_SCREENSHOT_TARGETS_PATH: \(identifier)"
        }
    }
}

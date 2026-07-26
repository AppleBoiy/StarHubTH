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

    private static func navigate(app: XCUIApplication, steps: [NavigationStep], targets: [String: String]) throws {
        for step in steps {
            switch step.action {
            case "click":
                let resolved = try resolve(step.identifier ?? "", targets: targets)
                let target = element(app: app, identifier: resolved)
                guard target.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound(resolved) }
                target.click()

            case "clickDescendant":
                guard let rowIdentifier = step.rowIdentifier, let descendantLabel = step.descendantLabel else { continue }
                let row = try resolve(rowIdentifier, targets: targets)
                let target = app.descendants(matching: .any).matching(
                    NSPredicate(format: "identifier == %@ AND label == %@", row, descendantLabel)
                ).firstMatch
                guard target.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound(row) }
                target.click()

            case "clickMenuItem":
                guard let menuIdentifier = step.menuIdentifier, let index = step.index else { continue }
                let resolved = try resolve(menuIdentifier, targets: targets)
                let menu = element(app: app, identifier: resolved)
                guard menu.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound(resolved) }
                menu.click()
                let item = app.menuItems.element(boundBy: index)
                guard item.waitForExistence(timeout: 5) else { throw CaptureError.elementNotFound("\(resolved) menu item \(index)") }
                item.click()

            case "clickSegment":
                guard let identifier = step.identifier else { continue }
                let picker = element(app: app, identifier: identifier)
                guard picker.waitForExistence(timeout: 10) else { throw CaptureError.elementNotFound(identifier) }
                if let segmentIndex = step.segmentIndex {
                    picker.buttons.element(boundBy: segmentIndex).click()
                } else if let segmentLabel = step.segmentLabel {
                    picker.descendants(matching: .any).matching(NSPredicate(format: "label == %@", segmentLabel)).firstMatch.click()
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
    private static func returnToBaseline(app: XCUIApplication) {
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

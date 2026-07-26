import XCTest

/// Exercises the live SMAPI log tail end-to-end: append a new line to the (fixture) log file
/// after the app has already started watching it, and confirm the line shows up in the Logs
/// view without restarting the app — proving the live tail (`LogStore.startSmapiLogWatcher`),
/// not just the initial load, actually works.
@MainActor
final class LogObserverRoundTripUITests: XCTestCase {
    private var app: XCUIApplication!
    private var workspace: UITestEnvironment.Workspace!

    override func setUp() async throws {
        continueAfterFailure = false
        workspace = UITestEnvironment.makeWorkspace(preInstallFixtureMod: false)
        app = AppLauncher.launch(environment: workspace.launchEnvironment)
    }

    override func tearDown() async throws {
        app.terminate()
        workspace.cleanUp()
    }

    func testANewSmapiLogLineAppearsLiveInTheLogsView() throws {
        let logsTab = app.buttons["sidebar-tab-Logs"]
        XCTAssertTrue(logsTab.waitForExistence(timeout: 15))
        logsTab.click()

        // Give LogsView.onAppear's startSmapiLogWatcher() a moment to finish its initial
        // (empty) load and open the file for tailing before we append — otherwise the write
        // could land before the tail's DispatchSource is watching it.
        Thread.sleep(forTimeInterval: 1)

        let marker = "UITEST-LIVE-LINE-\(UUID().uuidString.prefix(8))"
        let line = "[12:00:00 INFO SMAPI] \(marker)\n"
        guard let handle = FileHandle(forWritingAtPath: workspace.smapiLogPath.path) else {
            XCTFail("could not open the fixture SMAPI log for writing")
            return
        }
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()

        let entry = app.staticTexts[marker]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "a line appended to the live SMAPI log after launch should show up in the Logs view without restarting the app")
    }
}

import XCTest
@testable import StarHubTH

final class SmapiLogParserTests: XCTestCase {
    func testParseLog() {
        let log = """
        [10:11:12 INFO  SMAPI] SMAPI 4.0.0 with Stardew Valley 1.6.0
        [10:11:13 ALERT SMAPI] You can update 2 mods:
        [10:11:13 ALERT SMAPI]    Content Patcher 2.0.0: https://smapi.io/mods#Content_Patcher
        [10:11:13 ALERT SMAPI]    SpaceCore 1.5.0: https://smapi.io/mods#SpaceCore
        [10:11:14 INFO  SMAPI] Some other log
        [10:11:15 ERROR SMAPI] Skipped mods
        [10:11:15 ERROR SMAPI] -------------------------
        [10:11:15 ERROR SMAPI] These mods could not be added to your game.
        [10:11:15 ERROR SMAPI] - BadMod because it contains files, but none of them are manifest.json.
        [10:11:16 ERROR SMAPI] A random red error outside skipped mods.
        [10:11:17 INFO  SMAPI] Normal log again
        """

        let result = SmapiLogParser.parse(logContent: log)

        XCTAssertEqual(result.outOfDateMods.count, 2, "Should find 2 updates")
        if result.outOfDateMods.count >= 2 {
            XCTAssertEqual(result.outOfDateMods[0].name, "Content Patcher", "Update 1 name")
            XCTAssertEqual(result.outOfDateMods[0].version, "2.0.0", "Update 1 version")
            XCTAssertEqual(result.outOfDateMods[0].url, "https://smapi.io/mods#Content_Patcher", "Update 1 URL")

            XCTAssertEqual(result.outOfDateMods[1].name, "SpaceCore", "Update 2 name")
            XCTAssertEqual(result.outOfDateMods[1].version, "1.5.0", "Update 2 version")
        }

        XCTAssertEqual(result.errors.count, 2, "Should find 2 errors")
        if result.errors.count >= 2 {
            XCTAssertEqual(result.errors[0], "- BadMod because it contains files, but none of them are manifest.json.", "Error 1")
            XCTAssertEqual(result.errors[1], "A random red error outside skipped mods.", "Error 2")
        }
    }

    /// Regression test for a real bug: this fixture's sample had no blank lines between
    /// "ALERT SMAPI" entries, so it never caught that real SMAPI output does — a blank line
    /// right after "You can update N mods:" reset `isParsingUpdates` before a single real
    /// entry was read, silently leaving `outOfDateMods` empty on every real machine. Found by
    /// testing the app against a real, 122K-line SMAPI-latest.txt from an actual play session
    /// (this exact sample, trimmed) — this fixture is deliberately the real format, not an
    /// idealized one, so this exact class of bug can't slip back in unnoticed.
    func testParseLogWithBlankLinesBetweenUpdateEntries() {
        let log = """
        [10:11:12 INFO  SMAPI] SMAPI 4.5.2 with Stardew Valley 1.6.15
        [20:51:14 ALERT SMAPI] You can update 4 mods:

        [20:51:14 ALERT SMAPI]    East Scarp: C# 3.0.9: https://www.nexusmods.com/stardewvalley/mods/5787 (you have 3.0.8)

        [20:51:14 ALERT SMAPI]    TrinketTinker 1.8.0: https://www.nexusmods.com/stardewvalley/mods/29073 (you have 1.7.3)

        [10:11:17 INFO  SMAPI] Normal log again
        """

        let result = SmapiLogParser.parse(logContent: log)

        XCTAssertEqual(result.outOfDateMods.count, 2, "Blank lines between ALERT SMAPI entries must not end the update block early")
        if result.outOfDateMods.count >= 2 {
            XCTAssertEqual(result.outOfDateMods[0].name, "East Scarp: C#")
            XCTAssertEqual(result.outOfDateMods[1].name, "TrinketTinker")
        }
    }
}

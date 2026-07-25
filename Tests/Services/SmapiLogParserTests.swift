import Foundation

struct SmapiLogParserTests {
    static func run() {
        print("Running SmapiLogParserTests...")
        
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
        
        SimpleTestFramework.assertEqual(result.outOfDateMods.count, 2, "Should find 2 updates")
        if result.outOfDateMods.count >= 2 {
            SimpleTestFramework.assertEqual(result.outOfDateMods[0].name, "Content Patcher", "Update 1 name")
            SimpleTestFramework.assertEqual(result.outOfDateMods[0].version, "2.0.0", "Update 1 version")
            SimpleTestFramework.assertEqual(result.outOfDateMods[0].url, "https://smapi.io/mods#Content_Patcher", "Update 1 URL")
            
            SimpleTestFramework.assertEqual(result.outOfDateMods[1].name, "SpaceCore", "Update 2 name")
            SimpleTestFramework.assertEqual(result.outOfDateMods[1].version, "1.5.0", "Update 2 version")
        }
        
        SimpleTestFramework.assertEqual(result.errors.count, 2, "Should find 2 errors")
        if result.errors.count >= 2 {
            SimpleTestFramework.assertEqual(result.errors[0], "- BadMod because it contains files, but none of them are manifest.json.", "Error 1")
            SimpleTestFramework.assertEqual(result.errors[1], "A random red error outside skipped mods.", "Error 2")
        }
    }
}

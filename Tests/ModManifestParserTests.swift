import Foundation

struct ModManifestParserTests {
    static func run() {
        print("Running ModManifestParserTests...")
        
        let json = """
        {
            "Name": "Test Mod",
            "Author": "CJ",
            "Version": "1.2.3",
            "Description": "A test mod",
            "UniqueID": "cj.testmod",
            "UpdateKeys": ["Nexus: 1234"],
            "Dependencies": [
                {"UniqueID": "dep1", "IsRequired": true},
                {"UniqueID": "dep2", "IsRequired": false}
            ]
        }
        """
        
        let mod = ModManifestParser.parse(rawString: json, path: "/Mods/TestMod", relativePath: "TestMod", isEnabled: true, customTags: [:])
        
        SimpleTestFramework.assertTrue(mod != nil, "Mod should parse successfully")
        if let mod = mod {
            SimpleTestFramework.assertEqual(mod.name, "Test Mod", "Name should match")
            SimpleTestFramework.assertEqual(mod.author, "CJ", "Author should match")
            SimpleTestFramework.assertEqual(mod.version, "1.2.3", "Version should match")
            SimpleTestFramework.assertEqual(mod.uniqueId, "cj.testmod", "UniqueID should match")
            SimpleTestFramework.assertEqual(mod.nexusUrl, "https://www.nexusmods.com/stardewvalley/mods/1234", "NexusURL should match")
            SimpleTestFramework.assertTrue(mod.isEnabled, "Should be enabled")
            SimpleTestFramework.assertEqual(mod.dependencies.count, 2, "Should have 2 dependencies")
            SimpleTestFramework.assertTrue(mod.dependencies[0].isRequired, "First dep should be required")
            SimpleTestFramework.assertFalse(mod.dependencies[1].isRequired, "Second dep should not be required")
        }
    }
}

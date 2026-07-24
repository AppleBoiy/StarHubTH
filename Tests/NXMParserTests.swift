import Foundation

class NXMParserTests {
    static func run() {
        print("Running NXMParserTests...")
        testValidNXMLink()
        testInvalidNXMLink()
        testDifferentCaseNXMLink()
    }
    
    static func testValidNXMLink() {
        let url = URL(string: "nxm://stardewvalley/mods/123/files/456")!
        let result = NXMParser.parse(url: url)
        
        SimpleTestFramework.assertTrue(result != nil, "Should parse a valid NXM link")
        SimpleTestFramework.assertEqual(result?.modId, 123, "Should correctly extract mod ID")
        SimpleTestFramework.assertEqual(result?.fileId, 456, "Should correctly extract file ID")
    }
    
    static func testInvalidNXMLink() {
        let url1 = URL(string: "http://nexusmods.com/stardewvalley/mods/123/files/456")!
        let result1 = NXMParser.parse(url: url1)
        SimpleTestFramework.assertTrue(result1 == nil, "Should reject non-NXM schema")
        
        let url2 = URL(string: "nxm://skyrim/mods/123/files/456")!
        let result2 = NXMParser.parse(url: url2)
        SimpleTestFramework.assertTrue(result2 == nil, "Should reject non-StardewValley host")
        
        let url3 = URL(string: "nxm://stardewvalley/mods/abc/files/def")!
        let result3 = NXMParser.parse(url: url3)
        SimpleTestFramework.assertTrue(result3 == nil, "Should reject non-integer IDs")
    }
    
    static func testDifferentCaseNXMLink() {
        let url = URL(string: "NXM://StardewValley/MODS/789/FILES/101")!
        let result = NXMParser.parse(url: url)
        
        SimpleTestFramework.assertTrue(result != nil, "Should handle different casing")
        SimpleTestFramework.assertEqual(result?.modId, 789, "Should extract mod ID with case insensitivity")
        SimpleTestFramework.assertEqual(result?.fileId, 101, "Should extract file ID with case insensitivity")
    }
}

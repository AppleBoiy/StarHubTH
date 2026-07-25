import Foundation

class NXMParserTests {
    static func run() {
        print("Running NXMParserTests...")
        testValidNXMLink()
        testInvalidNXMLink()
        testDifferentCaseNXMLink()
        testNXMLinkWithKeyAndExpires()
    }

    static func testValidNXMLink() {
        let url = URL(string: "nxm://stardewvalley/mods/123/files/456")!
        let result = NXMParser.parse(url: url)

        SimpleTestFramework.assertTrue(result != nil, "Should parse a valid NXM link")
        if case .mod(let modId, let fileId, let key, let expires) = result {
            SimpleTestFramework.assertEqual(modId, 123, "Should correctly extract mod ID")
            SimpleTestFramework.assertEqual(fileId, 456, "Should correctly extract file ID")
            SimpleTestFramework.assertTrue(key == nil, "Should have no key when the link carries none")
            SimpleTestFramework.assertTrue(expires == nil, "Should have no expires when the link carries none")
        } else {
            SimpleTestFramework.assertTrue(false, "Result should be a mod")
        }
    }

    /// Nexus attaches `key`/`expires` to a "Download with Manager" link so a non-premium
    /// API key can authorize that single download. Dropping them silently breaks
    /// non-premium downloads entirely — see `downloadLink`'s doc comment.
    static func testNXMLinkWithKeyAndExpires() {
        let url = URL(string: "nxm://stardewvalley/mods/123/files/456?key=abc123&expires=1234567890")!
        let result = NXMParser.parse(url: url)

        guard case .mod(let modId, let fileId, let key, let expires) = result else {
            SimpleTestFramework.assertTrue(false, "Result should be a mod")
            return
        }
        SimpleTestFramework.assertEqual(modId, 123, "Should correctly extract mod ID")
        SimpleTestFramework.assertEqual(fileId, 456, "Should correctly extract file ID")
        SimpleTestFramework.assertEqual(key ?? "", "abc123", "Should extract the key query parameter")
        SimpleTestFramework.assertEqual(expires ?? "", "1234567890", "Should extract the expires query parameter")
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
        if case .mod(let modId, let fileId, _, _) = result {
            SimpleTestFramework.assertEqual(modId, 789, "Should extract mod ID with case insensitivity")
            SimpleTestFramework.assertEqual(fileId, 101, "Should extract file ID with case insensitivity")
        } else {
            SimpleTestFramework.assertTrue(false, "Result should be a mod")
        }
    }
}

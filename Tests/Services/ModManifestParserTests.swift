import XCTest
@testable import StarHubTH

final class ModManifestParserTests: XCTestCase {
    func testParseManifest() {
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

        XCTAssertTrue(mod != nil, "Mod should parse successfully")
        if let mod = mod {
            XCTAssertEqual(mod.name, "Test Mod", "Name should match")
            XCTAssertEqual(mod.author, "CJ", "Author should match")
            XCTAssertEqual(mod.version, "1.2.3", "Version should match")
            XCTAssertEqual(mod.uniqueId, "cj.testmod", "UniqueID should match")
            XCTAssertEqual(mod.nexusUrl, "https://www.nexusmods.com/stardewvalley/mods/1234", "NexusURL should match")
            XCTAssertTrue(mod.isEnabled, "Should be enabled")
            XCTAssertEqual(mod.dependencies.count, 2, "Should have 2 dependencies")
            XCTAssertTrue(mod.dependencies[0].isRequired, "First dep should be required")
            XCTAssertFalse(mod.dependencies[1].isRequired, "Second dep should not be required")
        }
    }
}

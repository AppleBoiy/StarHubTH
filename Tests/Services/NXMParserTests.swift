import XCTest
@testable import StarHubTH

final class NXMParserTests: XCTestCase {
    func testValidNXMLink() {
        let url = URL(string: "nxm://stardewvalley/mods/123/files/456")!
        let result = NXMParser.parse(url: url)

        XCTAssertTrue(result != nil, "Should parse a valid NXM link")
        if case .mod(let modId, let fileId, let key, let expires) = result {
            XCTAssertEqual(modId, 123, "Should correctly extract mod ID")
            XCTAssertEqual(fileId, 456, "Should correctly extract file ID")
            XCTAssertTrue(key == nil, "Should have no key when the link carries none")
            XCTAssertTrue(expires == nil, "Should have no expires when the link carries none")
        } else {
            XCTAssertTrue(false, "Result should be a mod")
        }
    }

    /// Nexus attaches `key`/`expires` to a "Download with Manager" link so a non-premium
    /// API key can authorize that single download. Dropping them silently breaks
    /// non-premium downloads entirely — see `downloadLink`'s doc comment.
    func testNXMLinkWithKeyAndExpires() {
        let url = URL(string: "nxm://stardewvalley/mods/123/files/456?key=abc123&expires=1234567890")!
        let result = NXMParser.parse(url: url)

        guard case .mod(let modId, let fileId, let key, let expires) = result else {
            XCTAssertTrue(false, "Result should be a mod")
            return
        }
        XCTAssertEqual(modId, 123, "Should correctly extract mod ID")
        XCTAssertEqual(fileId, 456, "Should correctly extract file ID")
        XCTAssertEqual(key ?? "", "abc123", "Should extract the key query parameter")
        XCTAssertEqual(expires ?? "", "1234567890", "Should extract the expires query parameter")
    }

    func testInvalidNXMLink() {
        let url1 = URL(string: "http://nexusmods.com/stardewvalley/mods/123/files/456")!
        let result1 = NXMParser.parse(url: url1)
        XCTAssertTrue(result1 == nil, "Should reject non-NXM schema")

        let url2 = URL(string: "nxm://skyrim/mods/123/files/456")!
        let result2 = NXMParser.parse(url: url2)
        XCTAssertTrue(result2 == nil, "Should reject non-StardewValley host")

        let url3 = URL(string: "nxm://stardewvalley/mods/abc/files/def")!
        let result3 = NXMParser.parse(url: url3)
        XCTAssertTrue(result3 == nil, "Should reject non-integer IDs")
    }

    func testDifferentCaseNXMLink() {
        let url = URL(string: "NXM://StardewValley/MODS/789/FILES/101")!
        let result = NXMParser.parse(url: url)

        XCTAssertTrue(result != nil, "Should handle different casing")
        if case .mod(let modId, let fileId, _, _) = result {
            XCTAssertEqual(modId, 789, "Should extract mod ID with case insensitivity")
            XCTAssertEqual(fileId, 101, "Should extract file ID with case insensitivity")
        } else {
            XCTAssertTrue(false, "Result should be a mod")
        }
    }
}

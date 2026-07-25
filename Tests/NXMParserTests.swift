import Foundation

class NXMParserTests {
    static func run() async {
        print("Running NXMParserTests...")
        testValidNXMLink()
        testInvalidNXMLink()
        testDifferentCaseNXMLink()
        testNXMLinkWithKeyAndExpires()
        await testNXMDownloadAndInstall()
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
    /// non-premium downloads entirely — see `getDownloadLink`'s doc comment.
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
    static func testNXMDownloadAndInstall() async {
        let defaults = UserDefaults(suiteName: "com.appleboiy.StarHubTH")
        let apiKey = defaults?.string(forKey: "nexusApiKey") ?? ""

        if apiKey.isEmpty {
            print("⚠️ SKIPPING testNXMDownloadAndInstall: No Nexus API Key found in com.appleboiy.StarHubTH defaults.")
            SimpleTestFramework.assertTrue(true, "Skipped due to missing API key")
            return
        }

        // Small mod for testing: Mail Framework Mod (modId: 1536, fileId: 128517, ~50KB)
        let urlString = "nxm://stardewvalley/mods/1536/files/128517"
        let url = URL(string: urlString)!

        guard let result = NXMParser.parse(url: url), case .mod(let modId, let fileId, let key, let expires) = result else {
            SimpleTestFramework.assertTrue(false, "Failed to parse test NXM link")
            return
        }

        let tempGameDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTH_Test_GameDir_\(UUID().uuidString)")
        let tempModsDir = tempGameDir.appendingPathComponent("Mods")
        try? FileManager.default.createDirectory(at: tempModsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempGameDir) }

        // Step 1: Fetch download link directly from LiveNexusAPIClient
        var downloadURL: URL? = nil
        do {
            let links = try await LiveNexusAPIClient.shared.getDownloadLink(modId: modId, fileId: fileId, key: key, expires: expires, apiKey: apiKey)
            downloadURL = URL(string: links.first?.URI ?? "")
            print("Got download URL: \(downloadURL?.absoluteString ?? "nil")")
        } catch {
            print("Failed to get download link: \(error.localizedDescription)")
        }
        guard let dlURL = downloadURL else {
            SimpleTestFramework.assertTrue(false, "No download URL returned from Nexus API")
            return
        }

        // Step 2: Download the zip
        let dlSemaphore = DispatchSemaphore(value: 0)
        var localZipURL: URL? = nil
        let dlTask = URLSession.shared.downloadTask(with: dlURL) { tempURL, _, error in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
            } else if let tempURL = tempURL {
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                try? FileManager.default.moveItem(at: tempURL, to: dest)
                localZipURL = dest
            }
            dlSemaphore.signal()
        }
        dlTask.resume()
        guard dlSemaphore.wait(timeout: .now() + .seconds(60)) == .success else {
            SimpleTestFramework.assertTrue(false, "Timed out downloading mod zip")
            return
        }
        guard let zipURL = localZipURL else {
            SimpleTestFramework.assertTrue(false, "Mod zip download failed")
            return
        }
        print("Downloaded zip to: \(zipURL.path)")
        
        // Step 3: Install via ModInstaller directly (no ViewModel, no DispatchQueue.main dependency)
        var installSuccess = false
        do {
            let names = try await ModInstaller.installFromZip(url: zipURL, gameDir: tempGameDir.path)
            print("Installed mods: \(names)")
            installSuccess = true
        } catch {
            print("Install error: \(error.localizedDescription)")
        }

        SimpleTestFramework.assertTrue(installSuccess, "Mod download and install from NXM link should succeed")
        
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempModsDir.path)) ?? []
        print("Mods dir contents: \(contents)")
        SimpleTestFramework.assertTrue(contents.count > 0, "Mods directory should contain the extracted mod")
    }
}

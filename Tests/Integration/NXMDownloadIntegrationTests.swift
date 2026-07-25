import Foundation

/// Live integration test: real Nexus API call + real download + real install, no stubs.
/// See LiveTestGate.swift — gated on STARHUB_SKIP_LIVE_TESTS, and separately short-circuits
/// if no real Nexus API key is configured locally.
class NXMDownloadIntegrationTests {
    static func run() async {
        print("Running NXMDownloadIntegrationTests...")
        await testNXMDownloadAndInstall()
    }

    static func testNXMDownloadAndInstall() async {
        guard !LiveTestGate.skipIfNeeded("testNXMDownloadAndInstall") else { return }

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
            let links = try await LiveNexusAPIClient.shared.downloadLink(modId: modId, fileId: fileId, key: key, expires: expires, apiKey: apiKey)
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

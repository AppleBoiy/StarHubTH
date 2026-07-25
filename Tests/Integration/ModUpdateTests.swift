import Foundation

class ModUpdateTests {
    static func run() async {
        print("Running ModUpdateTests...")
        await testAutoUpdateFlow()
    }

    static func testAutoUpdateFlow() async {
        guard !LiveTestGate.skipIfNeeded("testAutoUpdateFlow") else { return }

        let defaults = UserDefaults(suiteName: "com.appleboiy.StarHubTH")
        let apiKey = defaults?.string(forKey: "nexusApiKey") ?? ""

        if apiKey.isEmpty {
            print("⚠️ SKIPPING ModUpdateTests: No Nexus API Key found in com.appleboiy.StarHubTH defaults.")
            SimpleTestFramework.assertTrue(true, "Skipped due to missing API key")
            return
        }

        // Mod to test updating: "Mail Framework Mod" (Nexus ID: 1536)
        let modId = 1536

        let tempGameDir = FileManager.default.temporaryDirectory.appendingPathComponent("StarHubTH_UpdateTest_GameDir_\(UUID().uuidString)")
        let tempModsDir = tempGameDir.appendingPathComponent("Mods")
        try? FileManager.default.createDirectory(at: tempModsDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempGameDir) }

        // Step 1: Query API for all files for this mod to find the latest main file
        var latestFileId: Int? = nil
        do {
            let response = try await LiveNexusAPIClient.shared.modFiles(modId: modId, apiKey: apiKey)
            // Filter for main files (category 1) and sort by fileId descending to get the newest,
            // avoiding ancient .rar files that macOS's `unzip` can't extract.
            let mainFiles = response.files.filter { $0.categoryId == 1 }
            let newest = mainFiles.sorted { $0.fileId > $1.fileId }.first
            latestFileId = newest?.fileId ?? response.files.first?.fileId
            print("Got latest file ID from API: \(latestFileId ?? -1)")
        } catch {
            print("Failed to fetch mod files: \(error.localizedDescription)")
        }
        guard let targetFileId = latestFileId else {
            SimpleTestFramework.assertTrue(false, "No files returned for mod update check")
            return
        }

        // Step 2: Fetch premium download link
        var downloadURL: URL? = nil
        do {
            let links = try await LiveNexusAPIClient.shared.downloadLink(modId: modId, fileId: targetFileId, key: nil, expires: nil, apiKey: apiKey)
            downloadURL = URL(string: links.first?.URI ?? "")
            print("Got update download URL: \(downloadURL?.absoluteString ?? "nil")")
        } catch {
            print("Failed to get update download link: \(error.localizedDescription)")
        }
        guard let dlURL = downloadURL else {
            SimpleTestFramework.assertTrue(false, "No update download URL returned")
            return
        }

        // Step 3: Download the update zip
        let dlSemaphore = DispatchSemaphore(value: 0)
        var localZipURL: URL? = nil
        let dlTask = URLSession.shared.downloadTask(with: dlURL) { tempURL, _, error in
            if let error = error {
                print("Update download error: \(error.localizedDescription)")
            } else if let tempURL = tempURL {
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
                try? FileManager.default.moveItem(at: tempURL, to: dest)
                localZipURL = dest
            }
            dlSemaphore.signal()
        }
        dlTask.resume()
        guard dlSemaphore.wait(timeout: .now() + .seconds(60)) == .success else {
            SimpleTestFramework.assertTrue(false, "Timed out downloading update zip")
            return
        }
        guard let zipURL = localZipURL else {
            SimpleTestFramework.assertTrue(false, "Update zip download failed")
            return
        }

        // Step 4: Install the update
        var installSuccess = false
        do {
            let names = try await ModInstaller.installFromZip(url: zipURL, gameDir: tempGameDir.path)
            print("Installed update for mods: \(names)")
            installSuccess = true
        } catch {
            print("Update install error: \(error.localizedDescription)")
        }

        SimpleTestFramework.assertTrue(installSuccess, "Auto-update mod download and install should succeed")

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempModsDir.path)) ?? []
        SimpleTestFramework.assertTrue(contents.count > 0, "Mods directory should contain the updated mod")
    }
}

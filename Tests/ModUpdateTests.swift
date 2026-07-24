import Foundation

class ModUpdateTests {
    static func run() {
        print("Running ModUpdateTests...")
        testAutoUpdateFlow()
    }
    
    static func testAutoUpdateFlow() {
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
        let filesSemaphore = DispatchSemaphore(value: 0)
        var latestFileId: Int? = nil
        
        NexusAPIService.shared.getModFiles(modId: modId, apiKey: apiKey) { result in
            switch result {
            case .success(let response):
                // Filter for main files (category 1) and sort by fileId descending to get the newest,
                // avoiding ancient .rar files that macOS's `unzip` can't extract.
                let mainFiles = response.files.filter { $0.categoryId == 1 }
                let newest = mainFiles.sorted { $0.fileId > $1.fileId }.first
                latestFileId = newest?.fileId ?? response.files.first?.fileId
                print("Got latest file ID from API: \(latestFileId ?? -1)")
            case .failure(let error):
                print("Failed to fetch mod files: \(error.localizedDescription)")
            }
            filesSemaphore.signal()
        }
        guard filesSemaphore.wait(timeout: .now() + .seconds(15)) == .success else {
            SimpleTestFramework.assertTrue(false, "Timed out fetching mod files from Nexus API")
            return
        }
        guard let targetFileId = latestFileId else {
            SimpleTestFramework.assertTrue(false, "No files returned for mod update check")
            return
        }
        
        // Step 2: Fetch premium download link
        let linkSemaphore = DispatchSemaphore(value: 0)
        var downloadURL: URL? = nil
        
        NexusAPIService.shared.getDownloadLink(modId: modId, fileId: targetFileId, apiKey: apiKey) { result in
            switch result {
            case .success(let links):
                downloadURL = URL(string: links.first?.URI ?? "")
                print("Got update download URL: \(downloadURL?.absoluteString ?? "nil")")
            case .failure(let error):
                print("Failed to get update download link: \(error.localizedDescription)")
            }
            linkSemaphore.signal()
        }
        guard linkSemaphore.wait(timeout: .now() + .seconds(15)) == .success else {
            SimpleTestFramework.assertTrue(false, "Timed out fetching update download link")
            return
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
        let installSemaphore = DispatchSemaphore(value: 0)
        var installSuccess = false
        ModInstaller.installFromZip(url: zipURL, gameDir: tempGameDir.path) { result in
            switch result {
            case .success(let names):
                print("Installed update for mods: \(names)")
                installSuccess = true
            case .failure(let error):
                print("Update install error: \(error.localizedDescription)")
            }
            installSemaphore.signal()
        }
        guard installSemaphore.wait(timeout: .now() + .seconds(30)) == .success else {
            SimpleTestFramework.assertTrue(false, "Timed out installing update")
            return
        }
        
        SimpleTestFramework.assertTrue(installSuccess, "Auto-update mod download and install should succeed")
        
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempModsDir.path)) ?? []
        SimpleTestFramework.assertTrue(contents.count > 0, "Mods directory should contain the updated mod")
    }
}

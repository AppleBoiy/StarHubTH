import XCTest
@testable import StarHubTH

final class ModUpdateTests: XCTestCase {
    func testAutoUpdateFlow() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")

        let defaults = UserDefaults(suiteName: "com.appleboiy.StarHubTH")
        let apiKey = defaults?.string(forKey: "nexusApiKey") ?? ""
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

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
            XCTAssertTrue(false, "No files returned for mod update check")
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
            XCTAssertTrue(false, "No update download URL returned")
            return
        }

        // Step 3: Download the update zip
        var localZipURL: URL? = nil
        do {
            let (tempURL, _) = try await URLSession.shared.download(for: URLRequest(url: dlURL))
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
            try FileManager.default.moveItem(at: tempURL, to: dest)
            localZipURL = dest
        } catch {
            print("Update download error: \(error.localizedDescription)")
        }
        guard let zipURL = localZipURL else {
            XCTAssertTrue(false, "Update zip download failed")
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

        XCTAssertTrue(installSuccess, "Auto-update mod download and install should succeed")

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempModsDir.path)) ?? []
        XCTAssertTrue(contents.count > 0, "Mods directory should contain the updated mod")
    }
}

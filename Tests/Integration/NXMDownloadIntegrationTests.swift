import XCTest
@testable import StarHubTH

/// Live integration test: real Nexus API call + real download + real install, no stubs.
/// See LiveTestGate.swift — gated on STARHUB_SKIP_LIVE_TESTS, and separately short-circuits
/// if no real Nexus API key is configured locally.
final class NXMDownloadIntegrationTests: XCTestCase {
    func testNXMDownloadAndInstall() async throws {
        try XCTSkipIf(LiveTestGate.isSkipped, "STARHUB_SKIP_LIVE_TESTS=1")

        let apiKey = LiveTestGate.nexusApiKey
        try XCTSkipIf(apiKey.isEmpty, "No Nexus API Key found in com.appleboiy.StarHubTH defaults.")

        // Small mod for testing: Mail Framework Mod (modId: 1536, fileId: 128517, ~50KB)
        let urlString = "nxm://stardewvalley/mods/1536/files/128517"
        let url = URL(string: urlString)!

        guard let result = NXMParser.parse(url: url), case .mod(let modId, let fileId, let key, let expires) = result else {
            XCTAssertTrue(false, "Failed to parse test NXM link")
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
            XCTAssertTrue(false, "No download URL returned from Nexus API")
            return
        }

        // Step 2: Download the zip
        var localZipURL: URL? = nil
        do {
            let (tempURL, _) = try await URLSession.shared.download(for: URLRequest(url: dlURL))
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
            try FileManager.default.moveItem(at: tempURL, to: dest)
            localZipURL = dest
        } catch {
            print("Download error: \(error.localizedDescription)")
        }
        guard let zipURL = localZipURL else {
            XCTAssertTrue(false, "Mod zip download failed")
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

        XCTAssertTrue(installSuccess, "Mod download and install from NXM link should succeed")

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: tempModsDir.path)) ?? []
        print("Mods dir contents: \(contents)")
        XCTAssertTrue(contents.count > 0, "Mods directory should contain the extracted mod")
    }
}

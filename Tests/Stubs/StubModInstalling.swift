import Foundation

/// `@unchecked Sendable` — mutated only by the single test that configures it, before any
/// concurrent use, never actually shared across threads despite the `var` canned results.
final class StubModInstalling: ModInstalling, @unchecked Sendable {
    var installFromZipResult: Result<[String], ModInstallerError> = .success([])
    var installFromFolderResult: Result<[String], ModInstallerError> = .success([])

    func installFromZip(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try installFromZipResult.get()
    }

    func installFromFolder(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try installFromFolderResult.get()
    }
}

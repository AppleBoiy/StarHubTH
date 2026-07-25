import Foundation

final class StubModInstalling: ModInstalling {
    var installFromZipResult: Result<[String], ModInstallerError> = .success([])
    var installFromFolderResult: Result<[String], ModInstallerError> = .success([])

    func installFromZip(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try installFromZipResult.get()
    }

    func installFromFolder(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try installFromFolderResult.get()
    }
}

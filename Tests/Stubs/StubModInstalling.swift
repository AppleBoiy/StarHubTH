import Foundation

final class StubModInstalling: ModInstalling {
    var installFromZipResult: Result<[String], ModInstallerError> = .success([])
    var installFromFolderResult: Result<[String], ModInstallerError> = .success([])

    func installFromZip(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        completion(installFromZipResult)
    }

    func installFromFolder(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        completion(installFromFolderResult)
    }
}

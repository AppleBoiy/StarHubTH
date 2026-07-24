import Foundation

/// I/O boundary for installing a mod onto disk. `ModInstaller` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without touching the
/// filesystem or spawning `/usr/bin/unzip`.
protocol ModInstalling {
    func installFromZip(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void)
    func installFromFolder(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void)
}

extension ModInstaller: ModInstalling {
    func installFromZip(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        Self.installFromZip(url: url, gameDir: gameDir, completion: completion)
    }

    func installFromFolder(url: URL, gameDir: String, completion: @escaping (Result<[String], ModInstallerError>) -> Void) {
        Self.installFromFolder(url: url, gameDir: gameDir, completion: completion)
    }
}

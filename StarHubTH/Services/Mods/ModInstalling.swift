import Foundation

/// I/O boundary for installing a mod onto disk. `ModInstaller` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without touching the
/// filesystem or spawning `/usr/bin/unzip`.
protocol ModInstalling: Sendable {
    func installFromZip(url: URL, gameDir: String) async throws(ModInstallerError) -> [String]
    func installFromFolder(url: URL, gameDir: String) async throws(ModInstallerError) -> [String]
}

extension ModInstaller: ModInstalling {
    func installFromZip(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try await Self.installFromZip(url: url, gameDir: gameDir)
    }

    func installFromFolder(url: URL, gameDir: String) async throws(ModInstallerError) -> [String] {
        try await Self.installFromFolder(url: url, gameDir: gameDir)
    }
}

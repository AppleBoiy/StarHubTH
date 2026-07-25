import Foundation

/// I/O boundary for installing/uninstalling SMAPI. `SmapiInstaller` is the `Live`
/// implementation; a `Stub` conformance lets stores be tested without downloading or
/// running the SMAPI installer.
protocol SmapiInstalling {
    func install(gameDir: String) async -> SmapiInstallOutcome
    func uninstall(gameDir: String) async -> SmapiInstallOutcome
}

extension SmapiInstaller: SmapiInstalling {}

import Foundation

final class StubSmapiInstalling: SmapiInstalling {
    var installResult = SmapiInstallOutcome(success: true, messageKey: "", detail: nil)
    var uninstallResult = SmapiInstallOutcome(success: true, messageKey: "", detail: nil)

    func install(gameDir: String) async -> SmapiInstallOutcome { installResult }

    func uninstall(gameDir: String) async -> SmapiInstallOutcome { uninstallResult }
}

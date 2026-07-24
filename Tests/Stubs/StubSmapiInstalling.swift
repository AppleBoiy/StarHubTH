import Foundation

final class StubSmapiInstalling: SmapiInstalling {
    var installResult: (success: Bool, messageKey: String, detail: String?) = (true, "", nil)
    var uninstallResult: (success: Bool, messageKey: String, detail: String?) = (true, "", nil)

    func install(gameDir: String, completion: @escaping (Bool, String, String?) -> Void) {
        completion(installResult.success, installResult.messageKey, installResult.detail)
    }

    func uninstall(gameDir: String, completion: @escaping (Bool, String, String?) -> Void) {
        completion(uninstallResult.success, uninstallResult.messageKey, uninstallResult.detail)
    }
}

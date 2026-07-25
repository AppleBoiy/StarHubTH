import Foundation

/// Phase 4.8. Whatever is genuinely global: the selected game install, the detected
/// Steam identity, and SMAPI's installed-version status.
///
/// Not yet `@MainActor`, same reason as every store so far.
final class AppEnvironment: ObservableObject {
    @Published var gameDir: String {
        didSet {
            preferenceStoring.set(gameDir, forKey: "gameDir")
        }
    }
    @Published var steamUsername: String = ""
    @Published var steamAvatarPath: String?
    @Published var smapiInstalledVersion: String?   // nil = not installed
    @Published var showSmapiAlerts: Bool = false

    let smapiInstaller = SmapiInstaller()

    private let preferenceStoring: PreferenceStoring
    private let localization: LocalizationStore

    init(preferenceStoring: PreferenceStoring, localization: LocalizationStore) {
        self.preferenceStoring = preferenceStoring
        self.localization = localization

        // Automatically retrieve saved game path, or attempt to find the default Steam path on Mac
        let savedPath = preferenceStoring.string(forKey: "gameDir") ?? ""
        if !savedPath.isEmpty && FileManager.default.fileExists(atPath: savedPath) {
            self.gameDir = savedPath
        } else {
            self.gameDir = Self.detectDefaultGameDir()
        }
    }

    static func detectDefaultGameDir() -> String {
        let home = NSHomeDirectory()
        let steamPath = "\(home)/Library/Application Support/Steam/steamapps/common/Stardew Valley/Contents/MacOS"
        if FileManager.default.fileExists(atPath: steamPath) {
            return steamPath
        }

        let gogPath = "/Applications/Stardew Valley.app/Contents/MacOS"
        if FileManager.default.fileExists(atPath: gogPath) {
            return gogPath
        }

        return ""
    }

    func fetchSteamUser() {
        let home = NSHomeDirectory()
        let vdfPath = "\(home)/Library/Application Support/Steam/config/loginusers.vdf"
        guard let content = try? String(contentsOfFile: vdfPath, encoding: .utf8) else { return }

        // Very basic VDF parsing
        var currentSteamID = ""
        var personaName = ""

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let tLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if tLine.hasPrefix("\"7656") {
                currentSteamID = tLine.replacingOccurrences(of: "\"", with: "")
            }
            if tLine.hasPrefix("\"PersonaName\"") {
                let parts = tLine.components(separatedBy: "\"")
                if parts.count >= 4 { personaName = parts[3] }
            }
            if tLine.hasPrefix("\"MostRecent\"") && tLine.contains("\"1\"") {
                break
            }
        }

        if !personaName.isEmpty {
            self.steamUsername = personaName
        } else {
            let defaultName = NSFullUserName().components(separatedBy: " ").first ?? ""
            self.steamUsername = defaultName.isEmpty ? localization.L(L10n.VM.defaultFarmerName) : defaultName
        }

        if !currentSteamID.isEmpty {
            let avatarPathPng = "\(home)/Library/Application Support/Steam/config/avatarcache/\(currentSteamID).png"
            let avatarPathJpg = "\(home)/Library/Application Support/Steam/config/avatarcache/\(currentSteamID).jpg"
            if FileManager.default.fileExists(atPath: avatarPathPng) {
                self.steamAvatarPath = avatarPathPng
            } else if FileManager.default.fileExists(atPath: avatarPathJpg) {
                self.steamAvatarPath = avatarPathJpg
            }
        }
    }

    func checkSmapiVersion() {
        guard !gameDir.isEmpty else {
            self.smapiInstalledVersion = nil
            return
        }
        self.smapiInstalledVersion = SmapiInstaller.getInstalledVersion(gameDir: gameDir)
    }

    // Install SMAPI via Installer Helper
    func installSmapi(showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) {
        smapiInstaller.install(gameDir: gameDir) { [weak self] success, msgKey, detail in
            guard let self = self else { return }
            self.checkSmapiVersion()
            let message = detail != nil ? "\(self.localization.L(msgKey))\n\(detail!)" : self.localization.L(msgKey)
            showModal(message)
            log(message)
        }
    }

    // Uninstall SMAPI
    func uninstallSmapi(showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) {
        smapiInstaller.uninstall(gameDir: gameDir) { [weak self] success, msgKey, detail in
            guard let self = self else { return }
            self.checkSmapiVersion()
            let message = detail != nil ? "\(self.localization.L(msgKey))\n\(detail!)" : self.localization.L(msgKey)
            showModal(message)
            log(message)
        }
    }
}

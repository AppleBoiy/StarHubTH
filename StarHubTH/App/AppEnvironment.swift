import Foundation

/// Phase 4.8. Whatever is genuinely global: the selected game install, the detected
/// Steam identity, and SMAPI's installed-version status.
@MainActor
final class AppEnvironment: ObservableObject {
    @Published var gameDir: String {
        didSet {
            preferenceStoring.set(gameDir, forKey: "gameDir")
        }
    }
    @Published var steamUsername: String = ""
    @Published var steamAvatarPath: String?
    @Published var smapiInstalledVersion: String?   // nil = not installed

    let smapiInstaller = SmapiInstaller()

    /// When true, toggling a mod also cascades to its dependencies / dependents.
    /// Persisted in UserDefaults so SettingsView's @AppStorage stays in sync.
    var chainToggleDependencies: Bool {
        get { preferenceStoring.bool(forKey: "chainToggleDependencies") ?? true }
        set { preferenceStoring.set(newValue, forKey: "chainToggleDependencies") }
    }

    /// Read-only: SettingsView writes this key directly via its own `@AppStorage`,
    /// which shares the same UserDefaults storage this reads from.
    var nexusApiKey: String {
        preferenceStoring.string(forKey: "nexusApiKey") ?? ""
    }

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
        self.smapiInstalledVersion = SmapiInstaller.installedVersion(gameDir: gameDir)
    }

    // Install SMAPI via Installer Helper
    func installSmapi(showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        let outcome = await smapiInstaller.install(gameDir: gameDir)
        checkSmapiVersion()
        let message = outcome.detail.map { "\(localization.L(outcome.messageKey))\n\($0)" } ?? localization.L(outcome.messageKey)
        showModal(message)
        log(message)
    }

    // Uninstall SMAPI
    func uninstallSmapi(showModal: @escaping (String) -> Void, log: @escaping (String) -> Void) async {
        let outcome = await smapiInstaller.uninstall(gameDir: gameDir)
        checkSmapiVersion()
        let message = outcome.detail.map { "\(localization.L(outcome.messageKey))\n\($0)" } ?? localization.L(outcome.messageKey)
        showModal(message)
        log(message)
    }
}

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var smapiInstaller: SmapiInstaller


    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: 24) {
                
                // ── USER PROFILE HEADER ──
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        if let avatarPath = appEnvironment.steamAvatarPath, let nsImage = NSImage(contentsOfFile: avatarPath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                        }
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                            .background(Circle().fill(Color(nsColor: .windowBackgroundColor)).frame(width: 32, height: 32))
                            .offset(x: 35, y: 35)
                    }
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .padding(.top, 32)
                    
                    VStack(spacing: 4) {
                        Text(appEnvironment.steamUsername)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        Text(String(format: localizationStore.L(L10n.Home.versionString), appVersion))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // ── GAME INFO BLOCK ──
                StandardSection(title: localizationStore.L(L10n.Home.appInfo)) {
                    StandardRow(title: LocalizedStringKey(localizationStore.L(L10n.Home.developer)), detail: "AppleBoiy", showDivider: true)
                    StandardRow(
                        title: LocalizedStringKey(localizationStore.L(L10n.Home.modManager)),
                        detail: LocalizedStringKey(appEnvironment.smapiInstalledVersion == nil
                            ? localizationStore.L(L10n.Home.notInstalled)
                            : "SMAPI \(appEnvironment.smapiInstalledVersion ?? "")"),
                        showDivider: true
                    )
                    StandardRow(
                        title: LocalizedStringKey(localizationStore.L(L10n.Home.installedMods)),
                        detail: LocalizedStringKey(String(format: localizationStore.L(L10n.Home.itemCount), Int64(modsStore.mods.count))),
                        showDivider: false
                    )
                }
                .padding(.horizontal, 40)
                
                // ── SYSTEM SETTINGS SECTIONS ──
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Folder Settings
                    StandardSection(title: localizationStore.L(L10n.Home.gameFolder)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizationStore.L(L10n.Home.gamePath))
                                    .font(.system(size: 13))
                                if appEnvironment.gameDir.isEmpty {
                                    Text(localizationStore.L(L10n.Home.notSet))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(appEnvironment.gameDir)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Button(localizationStore.L(L10n.Home.selectFolder)) { appCoordinator.selectGameDir() }
                        }
                    }
                    
                    // SMAPI Settings
                    StandardSection(title: localizationStore.L(L10n.Home.smapiManager)) {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizationStore.L(L10n.Home.smapiStatus))
                                        .font(.system(size: 13))
                                    if let version = appEnvironment.smapiInstalledVersion {
                                        Text(String(format: localizationStore.L(L10n.Home.smapiInstalled), version))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(localizationStore.L(L10n.Home.smapiNotInstalled))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if smapiInstaller.isInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                } else if appEnvironment.smapiInstalledVersion == nil {
                                    Button(localizationStore.L(L10n.Home.installSmapi)) { Task { await appCoordinator.installSmapi() } }
                                } else {
                                    Button(localizationStore.L(L10n.Home.uninstall)) { Task { await appCoordinator.uninstallSmapi() } }
                                }
                            }
                            
                            if smapiInstaller.isInstalling {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: smapiInstaller.progress, total: 1.0)
                                        .progressViewStyle(.linear)
                                        .tint(.blue)
                                        .animation(.easeInOut, value: smapiInstaller.progress)
                                    Text(localizationStore.L(smapiInstaller.statusMessage))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
                
                // ── CORE EXTENSIONS SECTION ──
                StandardSection(title: localizationStore.L(L10n.Home.coreExtensions)) {
                    VStack(spacing: 0) {
                        let (cpStatus, cpMod) = coreModStatus(matching: "content patcher")
                        CoreModRow(title: "Content Patcher", status: cpStatus, mod: cpMod)
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1).padding(.leading, 12).padding(.vertical, 2)

                        let (scStatus, scMod) = coreModStatus(matching: "spacecore")
                        CoreModRow(title: "SpaceCore", status: scStatus, mod: scMod)
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1).padding(.leading, 12).padding(.vertical, 2)

                        let (thStatus, thMod) = coreModStatusThai()
                        CoreModRow(title: "Stardew Valley Thai", status: thStatus, mod: thMod)
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1).padding(.leading, 12).padding(.vertical, 2)

                        let (sveStatus, sveMod) = coreModStatus(matching: "stardew valley expanded")
                        CoreModRow(title: "Stardew Valley Expanded", status: sveStatus, mod: sveMod)
                    }
                    .padding(.vertical, -8)
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear { appCoordinator.refresh() }
    }
}


// MARK: - Core Mod Status

enum CoreModStatus {
    case enabledAndInstalled
    case installedButDisabled
    case notInstalled
}

extension HomeView {
    func coreModStatus(matching keyword: String) -> (CoreModStatus, Mod?) {
        let allMods = modsStore.mods.flatMap { $0.allMods }
        let matches = allMods.filter { $0.name.lowercased().contains(keyword) }
        guard !matches.isEmpty else { return (.notInstalled, nil) }

        // Prefer enabled mod if multiple match (e.g. "Content Patcher" vs "Content Patcher Animations")
        let exactEnabled  = matches.first { $0.name.lowercased() == keyword && $0.isEnabled }
        let anyEnabled    = matches.first { $0.isEnabled }
        let exactAny      = matches.first { $0.name.lowercased() == keyword }
        let mod = exactEnabled ?? anyEnabled ?? exactAny ?? matches.first!

        return (mod.isEnabled ? .enabledAndInstalled : .installedButDisabled, mod)
    }

    func coreModStatusThai() -> (CoreModStatus, Mod?) {
        let allMods = modsStore.mods.flatMap { $0.allMods }
        // Match by folder name first (exact), then by name containing "thai"
        let mod = allMods.first { $0.folderName.rawValue.lowercased() == "stardew valley - thai" && $0.isEnabled }
            ?? allMods.first { $0.name.localizedCaseInsensitiveContains("thai") && $0.isEnabled }
            ?? allMods.first { $0.folderName.rawValue.lowercased() == "stardew valley - thai" }
            ?? allMods.first { $0.name.localizedCaseInsensitiveContains("thai") }
        guard let mod = mod else { return (.notInstalled, nil) }
        return (mod.isEnabled ? .enabledAndInstalled : .installedButDisabled, mod)
    }
}

// Helper for core mod status rows
struct CoreModRow: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    let title: String
    let status: CoreModStatus
    let mod: Mod?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))

                // Author + version when installed, otherwise status text
                if let mod = mod {
                    HStack(spacing: 4) {
                        if !mod.author.isEmpty {
                            Text(mod.author)
                                .foregroundColor(.secondary)
                        }
                        if !mod.author.isEmpty && !mod.version.isEmpty {
                            Text("•").foregroundColor(.secondary.opacity(0.5))
                        }
                        if !mod.version.isEmpty {
                            Text("v\(mod.version)")
                                .foregroundColor(.secondary)
                                .fontDesign(.monospaced)
                        }
                    }
                    .font(.system(size: 11))

                    // Status label below author/version
                    Group {
                        switch status {
                        case .enabledAndInstalled:
                            Text(localizationStore.L(L10n.Home.installedAndEnabled))
                                .foregroundColor(.secondary)
                        case .installedButDisabled:
                            Text(localizationStore.L(L10n.Home.installedButDisabled))
                                .foregroundColor(.orange)
                        case .notInstalled:
                            EmptyView()
                        }
                    }
                    .font(.system(size: 11))
                } else {
                    Text(localizationStore.L(L10n.Home.notInstalledOrDisabled))
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
            Spacer()
            switch status {
            case .enabledAndInstalled:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .installedButDisabled:
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.orange)
            case .notInstalled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

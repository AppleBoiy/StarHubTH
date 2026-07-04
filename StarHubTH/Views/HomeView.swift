import SwiftUI

struct HomeView: View {
    @ObservedObject var vm: StarHubTHViewModel
    @ObservedObject var smapiInstaller: SmapiInstaller

    init(vm: StarHubTHViewModel) {
        self.vm = vm
        self.smapiInstaller = vm.smapiInstaller
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .center, spacing: 24) {
                
                // ── USER PROFILE HEADER ──
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.1))
                            .frame(width: 100, height: 100)
                        
                        if let avatarPath = vm.steamAvatarPath, let nsImage = NSImage(contentsOfFile: avatarPath) {
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
                        Text(vm.steamUsername)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                        Text(String(format: vm.L(L10n.Home.versionString), appVersion))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                // ── GAME INFO BLOCK ──
                StandardSection(title: vm.L(L10n.Home.appInfo)) {
                    StandardRow(title: LocalizedStringKey(vm.L(L10n.Home.developer)), detail: "AppleBoiy", showDivider: true)
                    StandardRow(
                        title: LocalizedStringKey(vm.L(L10n.Home.modManager)),
                        detail: LocalizedStringKey(vm.smapiInstalledVersion == nil
                            ? vm.L(L10n.Home.notInstalled)
                            : "SMAPI \(vm.smapiInstalledVersion!)"),
                        showDivider: true
                    )
                    StandardRow(
                        title: LocalizedStringKey(vm.L(L10n.Home.installedMods)),
                        detail: LocalizedStringKey(String(format: vm.L(L10n.Home.itemCount), Int64(vm.mods.count))),
                        showDivider: false
                    )
                }
                .padding(.horizontal, 40)
                
                // ── SYSTEM SETTINGS SECTIONS ──
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Folder Settings
                    StandardSection(title: vm.L(L10n.Home.gameFolder)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vm.L(L10n.Home.gamePath))
                                    .font(.system(size: 13))
                                if vm.gameDir.isEmpty {
                                    Text(vm.L(L10n.Home.notSet))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(vm.gameDir)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Button(vm.L(L10n.Home.selectFolder)) { vm.selectGameDir() }
                        }
                    }
                    
                    // SMAPI Settings
                    StandardSection(title: vm.L(L10n.Home.smapiManager)) {
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vm.L(L10n.Home.smapiStatus))
                                        .font(.system(size: 13))
                                    if let version = vm.smapiInstalledVersion {
                                        Text(String(format: vm.L(L10n.Home.smapiInstalled), version))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text(vm.L(L10n.Home.smapiNotInstalled))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if smapiInstaller.isInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                } else if vm.smapiInstalledVersion == nil {
                                    Button(vm.L(L10n.Home.installSmapi)) { vm.installSmapi() }
                                } else {
                                    Button(vm.L(L10n.Home.uninstall)) { vm.uninstallSmapi() }
                                }
                            }
                            
                            if smapiInstaller.isInstalling {
                                VStack(alignment: .leading, spacing: 4) {
                                    ProgressView(value: smapiInstaller.progress, total: 1.0)
                                        .progressViewStyle(.linear)
                                        .tint(.blue)
                                        .animation(.easeInOut, value: smapiInstaller.progress)
                                    Text(vm.L(smapiInstaller.statusMessage))
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
                StandardSection(title: vm.L(L10n.Home.coreExtensions)) {
                    VStack(spacing: 0) {
                        CoreModRow(
                            vm: vm,
                            title: "Content Patcher",
                            isInstalled: vm.mods.contains { $0.name.lowercased().contains("content patcher") && $0.isEnabled }
                        )
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1).padding(.leading, 12).padding(.vertical, 2)
                        
                        CoreModRow(
                            vm: vm,
                            title: "SpaceCore",
                            isInstalled: vm.mods.contains { $0.name.lowercased().contains("spacecore") && $0.isEnabled }
                        )
                        Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1).padding(.leading, 12).padding(.vertical, 2)
                        
                        CoreModRow(
                            vm: vm,
                            title: "Stardew Valley Thai",
                            isInstalled: vm.isThaiTranslationInstalled
                        )
                    }
                    .padding(.vertical, -8)
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}


// Helper for core mod status rows
struct CoreModRow: View {
    @ObservedObject var vm: StarHubTHViewModel
    let title: String
    let isInstalled: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                Text(vm.L(isInstalled ? L10n.Home.installedAndEnabled : L10n.Home.notInstalledOrDisabled))
                    .font(.system(size: 12))
                    .foregroundColor(isInstalled ? .secondary : .red)
            }
            Spacer()
            if isInstalled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

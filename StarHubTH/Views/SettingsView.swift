import SwiftUI
#if os(macOS)
import CoreServices
#endif

struct SettingsView: View {
    @ObservedObject var vm: StarHubTHViewModel
    
    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"
    @AppStorage("closeAfterLaunch") private var closeAfterLaunch: Bool = false
    @AppStorage("appColorScheme") private var appColorScheme: String = "System"
    @AppStorage("showDeveloperLogs") private var showDeveloperLogs: Bool = false
    @AppStorage("nexusApiKey") private var nexusApiKey: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                // ── Language ──
                StandardSection(title: vm.L(L10n.Settings.appLanguage)) {
                    HStack {
                        Text(vm.L(L10n.Settings.selectLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $vm.currentLanguage) {
                            Text(vm.L(L10n.Settings.languageThai)).tag("th")
                            Text(vm.L(L10n.Settings.languageEnglish)).tag("en")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                        
                        InfoPopoverButton(text: vm.L(L10n.Settings.selectLanguage))
                    }
                }
                
                // ── Nexus API ──
                StandardSection(
                    title: vm.L(L10n.Settings.nexusApiKey),
                    footer: vm.L(L10n.Settings.nexusApiSectionFooter)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            SecureField(vm.L(L10n.Settings.nexusApiKeyPlaceholder), text: $nexusApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !nexusApiKey.isEmpty {
                                Label(vm.L(L10n.Settings.nexusConnected), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 13, weight: .medium))
                            } else {
                                Label(vm.L(L10n.Settings.nexusNotConnected), systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            
                            Button(action: {
                                if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(vm.L(L10n.Settings.nexusGetApiKey))
                                    Image(systemName: "arrow.up.right.square")
                                }
                            }
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.nexusApiKeyHint))
                        }
                    }
                }
                
                // ── Nexus Protocol Handler ──
                StandardSection(
                    title: "Nexus Download Handler",
                    footer: "Allows StarHubTH to automatically intercept and handle 'Mod Manager Download' links (nxm://) from the Nexus Mods website."
                ) {
                    HStack(spacing: 12) {
                        Text("Register as default handler for Nexus Mods links")
                            .font(.system(size: 13))
                        Spacer()
                        Button("Set as Default") {
                            #if os(macOS)
                            let scheme = "nxm" as CFString
                            let bundleID = "com.appleboiy.StarHubTH" as CFString
                            let status = LSSetDefaultHandlerForURLScheme(scheme, bundleID)
                            if status == 0 {
                                vm.showModal(message: "StarHubTH is now successfully registered as your default Nexus Mods handler!")
                            } else {
                                vm.showModal(message: "Failed to set default handler. macOS returned status code: \(status)")
                            }
                            #endif
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        
                        InfoPopoverButton(text: "If you have Vortex or Stardrop installed, macOS might send Nexus downloads to them instead. Click this to route them back to StarHubTH.")
                    }
                }
                
                // ── Launch Options ──
                StandardSection(
                    title: vm.L(L10n.Settings.launchOptions),
                    footer: vm.L(L10n.Settings.footerLaunch)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.L(L10n.Settings.defaultLaunchMode))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $launchProfile) {
                                Text(vm.L(L10n.Settings.playSMAPI)).tag("SMAPI")
                                Text(vm.L(L10n.Settings.vanillaGame)).tag("Vanilla")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .fixedSize()
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.hintNextLaunchMode))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(vm.L(L10n.Settings.closeLauncher))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $closeAfterLaunch)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .controlSize(.small)
                                .labelsHidden()
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.hintSaveResources))
                        }
                    }
                }
                
                // ── Backup ──
                StandardSection(
                    title: vm.L(L10n.Settings.backup),
                    footer: vm.L(L10n.Settings.footerBackup)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.L(L10n.Settings.backupSaves))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { vm.backupAllSaves() }) {
                                Text(vm.L(L10n.Settings.backupSavesButton))
                            }
                            InfoPopoverButton(text: vm.L(L10n.Settings.hintCompressSaves))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(vm.L(L10n.Settings.backupMods))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { vm.backupAllMods() }) {
                                Text(vm.L(L10n.Settings.backupModsButton))
                            }
                            InfoPopoverButton(text: vm.L(L10n.Settings.hintCompressMods))
                        }
                    }
                }
                
                // ── Appearance ──
                StandardSection(
                    title: vm.L(L10n.Settings.appearance),
                    footer: vm.L(L10n.Settings.footerAppearance)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.L(L10n.Settings.appTheme))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $appColorScheme) {
                                Text(vm.L(L10n.Settings.themeSystem)).tag("System")
                                Text(vm.L(L10n.Settings.themeLight)).tag("Light")
                                Text(vm.L(L10n.Settings.themeDark)).tag("Dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .fixedSize()
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.selectLanguage))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(vm.L(L10n.Settings.showDevLogs))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $showDeveloperLogs)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .controlSize(.small)
                                .labelsHidden()
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.hintDevLogs))
                        }
                    }
                }
                
                // ── Mod Behavior ──
                StandardSection(
                    title: vm.L(L10n.Settings.modBehavior),
                    footer: vm.L(L10n.Settings.chainToggleHint)
                ) {
                    HStack {
                        Text(vm.L(L10n.Settings.chainToggle))
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { vm.chainToggleDependencies },
                            set: { vm.chainToggleDependencies = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .controlSize(.small)
                        .labelsHidden()
                        
                        InfoPopoverButton(text: vm.L(L10n.Settings.chainToggleHint))
                    }
                }

                // ── Management ──
                StandardSection(
                    title: vm.L(L10n.Settings.management),
                    footer: vm.L(L10n.Settings.footerManagement)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(vm.L(L10n.Settings.savesFolder))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { vm.openSavesFolder() }) {
                                Text(vm.L(L10n.Settings.openFolder))
                            }
                            InfoPopoverButton(text: vm.L(L10n.Settings.openFolder))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(vm.L(L10n.Settings.clearDisabledMods))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { vm.cleanDisabledMods() }) {
                                Text(vm.L(L10n.Settings.deleteJunkMods))
                            }
                            .foregroundColor(.red)
                            
                            InfoPopoverButton(text: vm.L(L10n.Settings.clearDisabledMods), color: .red.opacity(0.8))
                        }
                    }
                }
            }
            .padding(40)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

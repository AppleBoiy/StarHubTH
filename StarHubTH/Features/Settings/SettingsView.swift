import SwiftUI
#if os(macOS)
import CoreServices
#endif

struct SettingsView: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator

    @AppStorage("launchProfile") private var launchProfile: String = "SMAPI"
    @AppStorage("closeAfterLaunch") private var closeAfterLaunch: Bool = false
    @AppStorage("appColorScheme") private var appColorScheme: String = "System"
    @AppStorage("showDeveloperLogs") private var showDeveloperLogs: Bool = false
    @AppStorage("nexusApiKey") private var nexusApiKey: String = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                
                // ── Language ──
                StandardSection(title: localizationStore.L(L10n.Settings.appLanguage)) {
                    HStack {
                        Text(localizationStore.L(L10n.Settings.selectLanguage))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $localizationStore.currentLanguage) {
                            Text(localizationStore.L(L10n.Settings.languageThai)).tag("th")
                            Text(localizationStore.L(L10n.Settings.languageEnglish)).tag("en")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .fixedSize()
                        
                        InfoPopoverButton(text: localizationStore.L(L10n.Settings.selectLanguage))
                    }
                }
                
                // ── Nexus API ──
                StandardSection(
                    title: localizationStore.L(L10n.Settings.nexusApiKey),
                    footer: localizationStore.L(L10n.Settings.nexusApiSectionFooter)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            SecureField(localizationStore.L(L10n.Settings.nexusApiKeyPlaceholder), text: $nexusApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !nexusApiKey.isEmpty {
                                Label(localizationStore.L(L10n.Settings.nexusConnected), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 13, weight: .medium))
                            } else {
                                Label(localizationStore.L(L10n.Settings.nexusNotConnected), systemImage: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 13, weight: .medium))
                            }
                            
                            Button(action: {
                                if let url = URL(string: "https://www.nexusmods.com/users/myaccount?tab=api+access") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(localizationStore.L(L10n.Settings.nexusGetApiKey))
                                    Image(systemName: "arrow.up.right.square")
                                }
                            }
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.nexusApiKeyHint))
                        }
                    }
                }
                
                // ── Nexus Protocol Handler ──
                StandardSection(
                    title: localizationStore.L(L10n.SettingsExtra.nexusHandlerTitle),
                    footer: localizationStore.L(L10n.SettingsExtra.nexusHandlerDesc)
                ) {
                    HStack(spacing: 12) {
                        Text(localizationStore.L(L10n.SettingsExtra.nexusHandlerTitle))
                            .font(.system(size: 13))
                        Spacer()
                        Button(localizationStore.L(L10n.SettingsExtra.setAsDefault)) {
                            #if os(macOS)
                            let scheme = "nxm" as CFString
                            let bundleID = "com.appleboiy.StarHubTH" as CFString
                            let status = LSSetDefaultHandlerForURLScheme(scheme, bundleID)
                            if status == 0 {
                                alertStore.show("StarHubTH is now successfully registered as your default Nexus Mods handler!")
                            } else {
                                alertStore.show("Failed to set default handler. macOS returned status code: \(status)")
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
                    title: localizationStore.L(L10n.Settings.launchOptions),
                    footer: localizationStore.L(L10n.Settings.footerLaunch)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(localizationStore.L(L10n.Settings.defaultLaunchMode))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $launchProfile) {
                                Text(localizationStore.L(L10n.Settings.playSMAPI)).tag("SMAPI")
                                Text(localizationStore.L(L10n.Settings.vanillaGame)).tag("Vanilla")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .fixedSize()
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.hintNextLaunchMode))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(localizationStore.L(L10n.Settings.closeLauncher))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $closeAfterLaunch)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .controlSize(.small)
                                .labelsHidden()
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.hintSaveResources))
                        }
                    }
                }
                
                // ── Backup ──
                StandardSection(
                    title: localizationStore.L(L10n.Settings.backup),
                    footer: localizationStore.L(L10n.Settings.footerBackup)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(localizationStore.L(L10n.Settings.backupSaves))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { appCoordinator.backupAllSaves() }) {
                                Text(localizationStore.L(L10n.Settings.backupSavesButton))
                            }
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.hintCompressSaves))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(localizationStore.L(L10n.Settings.backupMods))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { appCoordinator.backupAllMods() }) {
                                Text(localizationStore.L(L10n.Settings.backupModsButton))
                            }
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.hintCompressMods))
                        }
                    }
                }
                
                // ── Appearance ──
                StandardSection(
                    title: localizationStore.L(L10n.Settings.appearance),
                    footer: localizationStore.L(L10n.Settings.footerAppearance)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(localizationStore.L(L10n.Settings.appTheme))
                                .font(.system(size: 13))
                            Spacer()
                            Picker("", selection: $appColorScheme) {
                                Text(localizationStore.L(L10n.Settings.themeSystem)).tag("System")
                                Text(localizationStore.L(L10n.Settings.themeLight)).tag("Light")
                                Text(localizationStore.L(L10n.Settings.themeDark)).tag("Dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .fixedSize()
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.selectLanguage))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(localizationStore.L(L10n.Settings.showDevLogs))
                                .font(.system(size: 13))
                            Spacer()
                            Toggle("", isOn: $showDeveloperLogs)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .controlSize(.small)
                                .labelsHidden()
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.hintDevLogs))
                        }
                    }
                }
                
                // ── Mod Behavior ──
                StandardSection(
                    title: localizationStore.L(L10n.Settings.modBehavior),
                    footer: localizationStore.L(L10n.Settings.chainToggleHint)
                ) {
                    HStack {
                        Text(localizationStore.L(L10n.Settings.chainToggle))
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { appEnvironment.chainToggleDependencies },
                            set: { appEnvironment.chainToggleDependencies = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .controlSize(.small)
                        .labelsHidden()
                        
                        InfoPopoverButton(text: localizationStore.L(L10n.Settings.chainToggleHint))
                    }
                }

                // ── Management ──
                StandardSection(
                    title: localizationStore.L(L10n.Settings.management),
                    footer: localizationStore.L(L10n.Settings.footerManagement)
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(localizationStore.L(L10n.Settings.savesFolder))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { savesStore.openSavesFolder() }) {
                                Text(localizationStore.L(L10n.Settings.openFolder))
                            }
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.openFolder))
                        }
                        
                        Divider().padding(.leading, 0)
                        
                        HStack {
                            Text(localizationStore.L(L10n.Settings.clearDisabledMods))
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { appCoordinator.cleanDisabledMods() }) {
                                Text(localizationStore.L(L10n.Settings.deleteJunkMods))
                            }
                            .foregroundColor(.red)
                            
                            InfoPopoverButton(text: localizationStore.L(L10n.Settings.clearDisabledMods), color: .red.opacity(0.8))
                        }
                    }
                }
            }
            .padding(40)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

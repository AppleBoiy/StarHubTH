import SwiftUI

struct ModProfilesView: View {
    @EnvironmentObject var profilesStore: ProfilesStore
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isShowingNewProfileAlert = false
    @State private var newProfileName = ""
    @State private var selectedProfileForDetail: ModProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // List Container
            VStack(spacing: 0) {
                if profilesStore.modProfiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(localizationStore.L(L10n.Profiles.noProfiles))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(Array(profilesStore.modProfiles.enumerated()), id: \.element.id) { index, profile in
                        ProfileRow(profile: profile, isActive: profilesStore.activeProfileId == profile.id, selectedProfileForDetail: $selectedProfileForDetail)
                        
                        if index < profilesStore.modProfiles.count - 1 {
                            Divider()
                                .padding(.leading, 64) // Align with text
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            
            // Add buttons below list, right-aligned
            HStack {
                Button(action: {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            let (collection, newProfile) = try profilesStore.importProfile(from: url)
                            profilesStore.modProfiles.append(newProfile)
                            profilesStore.saveProfiles()
                            // Queue installer. This local collection format has no
                            // nxm:// key/expires pair to authorize a direct API download
                            // for a non-premium account (see NXMParser's doc comment), so
                            // opening each missing mod's Nexus page for a manual download
                            // is the correct behavior here, not a stand-in for a real
                            // download that got cut — the message says so explicitly.
                            let missingIds = profilesStore.missingNexusIds(in: collection, currentMods: modsStore.mods, nexusApiKey: appEnvironment.nexusApiKey)
                            if !missingIds.isEmpty {
                                alertStore.show(String(format: localizationStore.L(L10n.VM.collectionImportedMissing), missingIds.count))
                                openMissingModPages(missingIds)
                            } else {
                                alertStore.show(localizationStore.L(L10n.VM.collectionImported))
                            }
                        } catch {
                            alertStore.show(String(format: localizationStore.L(L10n.VM.collectionImportFailed), error.localizedDescription))
                        }
                    }
                }) {
                    Text(localizationStore.L(L10n.Profiles.importCollection))
                }
                
                Spacer()
                Button(action: {
                    isShowingNewProfileAlert = true
                }) {
                    Text(localizationStore.L(L10n.Profiles.addProfile))
                }
            }
            
            Spacer()
        }
        .padding(30)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $selectedProfileForDetail) { profile in
            ProfileDetailSheet(profile: profile, isPresented: Binding(
                get: { selectedProfileForDetail != nil },
                set: { if !$0 { selectedProfileForDetail = nil } }
            ))
        }
        .alert(localizationStore.L(L10n.Profiles.createNewProfile), isPresented: $isShowingNewProfileAlert) {
            TextField(localizationStore.L(L10n.Profiles.profileNamePlaceholder), text: $newProfileName)
            Button(localizationStore.L(L10n.Profiles.save)) {
                if !newProfileName.isEmpty {
                    appCoordinator.createProfile(name: newProfileName)
                    newProfileName = ""
                }
            }
            Button(localizationStore.L(L10n.Profiles.cancel), role: .cancel) {
                newProfileName = ""
            }
        } message: {
            Text(localizationStore.L(L10n.Profiles.newProfileNote))
        }
    }

    /// Opens each missing mod's Nexus page with a short stagger between them, instead of
    /// firing every NSWorkspace.shared.open call in one tight loop — a dozen-plus tabs
    /// opening at once reads as a popup storm, not a helpful "here's what to grab."
    private func openMissingModPages(_ missingIds: [String]) {
        Task {
            for id in missingIds {
                if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(id)") {
                    NSWorkspace.shared.open(url)
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: ModProfile
    let isActive: Bool
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Binding var selectedProfileForDetail: ModProfile?
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Circular Avatar
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isActive ? .white : .primary)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.primary)
                Text(localizationStore.L(isActive ? L10n.Profiles.inUse : L10n.Profiles.inactive))
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? .secondary : .secondary)
            }
            
            Spacer()
            
            // Info button (or delete)
            Button(action: {
                selectedProfileForDetail = profile
            }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(localizationStore.L(L10n.Profiles.viewDetails))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onTapGesture {
            appCoordinator.applyProfile(id: profile.id)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ProfileDetailSheet: View {
    let profile: ModProfile
    @EnvironmentObject var profilesStore: ProfilesStore
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @Binding var isPresented: Bool
    
    @State private var editName: String = ""
    @State private var editedEnabledMods: Set<Mod.UniqueID> = []
    @State private var isShowingModsPopover = false

    /// Mods for the checklist — top-level groups and standalone mods only.
    /// Groups show as a single row; toggling a group toggles all its children.
    private var flatMods: [Mod] {
        modsStore.mods
            .filter { !$0.uniqueId.rawValue.isEmpty || $0.isGroup }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// All uniqueIds covered by a Mod (group = all children's ids, single mod = its own id).
    private func idsFor(_ mod: Mod) -> [Mod.UniqueID] {
        if case .group(let children) = mod.kind {
            return children.map { $0.uniqueId }.filter { !$0.rawValue.isEmpty }
        }
        return mod.uniqueId.rawValue.isEmpty ? [] : [mod.uniqueId]
    }

    /// Whether a mod (or group) is fully checked in the current selection.
    private func isChecked(_ mod: Mod) -> Bool {
        let ids = idsFor(mod)
        return !ids.isEmpty && ids.allSatisfy { editedEnabledMods.contains($0) }
    }

    /// Apply chain-toggle logic on the in-memory editedEnabledMods set
    /// by delegating to the ViewModel's shared logic.
    private func applyChain(mod: Mod, enable: Bool) {
        editedEnabledMods = appCoordinator.applyChainToSet(mod: mod, enable: enable, currentEnabled: editedEnabledMods)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Big Avatar
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 80, height: 80)
                
                Text(String(profile.name.prefix(1)).uppercased())
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 24)
            .padding(.bottom, 24)
            
            // Settings Box
            VStack(spacing: 0) {
                // Name Row
                HStack {
                    Text(localizationStore.L(L10n.Profiles.profileName))
                        .font(.system(size: 13))
                    Spacer()
                    TextField("", text: $editName)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 13))
                        .frame(width: 200)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().padding(.leading, 16)
                
                // Manage Mods Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: localizationStore.L(L10n.Profiles.modsInProfile), editedEnabledMods.count))
                            .font(.system(size: 13))
                        Text(localizationStore.L(L10n.Profiles.selectMods))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(localizationStore.L(L10n.Profiles.manage)) {
                        isShowingModsPopover = true
                    }
                    .popover(isPresented: $isShowingModsPopover, arrowEdge: .trailing) {
                        VStack(spacing: 0) {
                            HStack {
                                Text(localizationStore.L(L10n.Profiles.manageMods))
                                    .font(.headline)
                                Spacer()
                                Button(localizationStore.L(L10n.Profiles.selectAll)) {
                                    editedEnabledMods = Set(flatMods.flatMap { idsFor($0) })
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                .font(.system(size: 11))
                                .pointingHandCursor()
                                
                                Button(localizationStore.L(L10n.Profiles.deselectAll)) {
                                    editedEnabledMods.removeAll()
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                                .font(.system(size: 11))
                                .pointingHandCursor()
                            }
                            .padding()
                            Divider()
                            
                            ScrollView {
                                VStack(spacing: 8) {
                                    ForEach(flatMods) { mod in
                                        Toggle(mod.name, isOn: Binding(
                                            get: { isChecked(mod) },
                                            set: { isOn in
                                                if appEnvironment.chainToggleDependencies {
                                                    // For groups, chain-apply each child
                                                    if case .group(let children) = mod.kind {
                                                        for child in children where !child.uniqueId.rawValue.isEmpty {
                                                            applyChain(mod: child, enable: isOn)
                                                        }
                                                    } else {
                                                        applyChain(mod: mod, enable: isOn)
                                                    }
                                                } else {
                                                    let ids = idsFor(mod)
                                                    if isOn { ids.forEach { editedEnabledMods.insert($0) } }
                                                    else    { ids.forEach { editedEnabledMods.remove($0) } }
                                                }
                                            }
                                        ))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding()
                            }
                        }
                        .frame(width: 320, height: 400)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().padding(.leading, 16)
                
                // Export Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationStore.L(L10n.Profiles.exportCollection))
                            .font(.system(size: 13))
                        Text(localizationStore.L(L10n.Profiles.exportCollectionHint))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(localizationStore.L(L10n.Settings.configSave)) {
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.json]
                        panel.nameFieldStringValue = "\(profile.name.replacingOccurrences(of: " ", with: "_")).json"
                        if panel.runModal() == .OK, let url = panel.url {
                            do {
                                try profilesStore.exportProfile(profile, mods: modsStore.mods, to: url)
                                alertStore.show( localizationStore.L(L10n.VM.collectionExported))
                            } catch {
                                alertStore.show( String(format: localizationStore.L(L10n.VM.collectionExportFailed), error.localizedDescription))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().padding(.leading, 16)
                
                // Delete Row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localizationStore.L(L10n.Profiles.deleteProfile))
                            .font(.system(size: 13))
                        Text(localizationStore.L(L10n.Profiles.deleteNote))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(localizationStore.L(L10n.Profiles.delete)) {
                        profilesStore.deleteProfile(id: profile.id)
                        isPresented = false
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Cancel / OK
            HStack {
                Button(action: {
                    // Action for Help
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help(localizationStore.L(L10n.Profiles.help))
                
                Spacer()
                
                Button(localizationStore.L(L10n.Profiles.cancel)) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button(localizationStore.L(L10n.Profiles.ok)) {
                    let finalMods = Array(editedEnabledMods)
                    appCoordinator.updateProfile(id: profile.id, newName: editName, enabledModIds: finalMods)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            editName = profile.name
            // If this is the active profile, reflect actual filesystem state
            if profilesStore.activeProfileId == profile.id {
                editedEnabledMods = Set(
                    modsStore.mods.flatMap { mod -> [Mod.UniqueID] in
                        if case .group(let children) = mod.kind {
                            return children.filter { $0.isEnabled }.map { $0.uniqueId }
                        }
                        return mod.isEnabled ? [mod.uniqueId] : []
                    }.filter { !$0.rawValue.isEmpty }
                )
            } else {
                editedEnabledMods = Set(profile.enabledModIds)
            }
        }    }
}

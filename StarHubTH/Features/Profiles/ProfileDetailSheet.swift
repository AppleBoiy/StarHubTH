import SwiftUI

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
        }
    }
}

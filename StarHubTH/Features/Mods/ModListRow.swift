import SwiftUI

struct ModListRow: View {
    let mod: Mod
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    @State private var isHovered = false
    var isChild: Bool = false
    var isGroupHeader: Bool = false
    @Binding var isExpanded: Bool
    @State private var localIsOn: Bool?

    private var hasConfigJson: Bool {
        guard !mod.isGroup else { return false }
        let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
        let path = URL(fileURLWithPath: appEnvironment.gameDir)
            .appendingPathComponent(baseFolder)
            .appendingPathComponent(mod.folderName.rawValue)
            .appendingPathComponent("config.json")
            .path
        return FileManager.default.fileExists(atPath: path)
    }

    /// Returns a matching ModUpdateInfo if this mod has an update available
    private var pendingUpdate: ModUpdateInfo? {
        guard !mod.isGroup else { return nil }
        return modsStore.outOfDateMods.first {
            $0.name.localizedCaseInsensitiveCompare(mod.name) == .orderedSame ||
            mod.name.lowercased().contains($0.name.lowercased())
        }
    }

    private var hasMissingDependencies: Bool {
        guard mod.isEnabled && !mod.isGroup else { return false }
        for dep in mod.dependencies where dep.isRequired {
            if modsStore.resolveDependencyStatus(for: dep.uniqueId) != .active {
                return true
            }
        }
        return false
    }

    var body: some View {
        HStack(spacing: 12) {

            // Chevron space
            if !isChild {
                ZStack {
                    if isGroupHeader {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 14, alignment: .center)
            } else {
                Spacer().frame(width: 32)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(mod.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(!mod.isEnabled ? .secondary : .primary)
                        .lineLimit(1)

                    if hasMissingDependencies {
                        let names = mod.dependencies.filter { $0.isRequired && modsStore.resolveDependencyStatus(for: $0.uniqueId) != .active }.map { $0.uniqueId.rawValue }.joined(separator: ", ")
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help(String(format: localizationStore.L(L10n.Mods.missingDependencies), names))
                    }

                    // Type tag badge
                    if !mod.tag.isEmpty && !isChild {
                        Text(localizationStore.localizedTag(mod.tag))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }

                    // Update available badge
                    if pendingUpdate != nil {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 9))
                            Text(localizationStore.L(L10n.Mods.updateAvailable))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                    }
                }

                if mod.name != mod.folderName.rawValue {
                    Text(mod.folderName.rawValue)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }

                if !mod.isGroup {
                    HStack(spacing: 6) {
                        Text(mod.author)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("v\(mod.version)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                } else {
                    let displayAuthor = localizationStore.L(mod.author)
                    let countStr = Int(mod.description).map { String(format: localizationStore.L(L10n.Mods.groupCount), $0) } ?? mod.description
                    Text("\(displayAuthor) • \(countStr)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                let missingDeps = modsStore.missingDependencies(for: mod)
                if !missingDeps.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: localizationStore.L(L10n.Mods.missingDependencies), missingDeps.map { $0.rawValue }.joined(separator: ", ")))
                            .foregroundColor(.yellow)
                    }
                    .font(.system(size: 11))
                    .padding(.top, 2)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 10) {
                // Update button (only when an update is available)
                if let update = pendingUpdate {
                    Button {
                        if !appEnvironment.nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                            Task { await appCoordinator.downloadAndInstallUpdate(for: update, nexusId: Mod.NexusID(rawValue: nId)) }
                        } else if let url = URL(string: update.url) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if modsStore.downloadingMods.contains(mod.name) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                Text(localizationStore.L(L10n.Settings.nexusDownloading))
                                    .font(.system(size: 11, weight: .medium))
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11))
                                Text(!appEnvironment.nexusApiKey.isEmpty ? localizationStore.L(L10n.Settings.nexusDownloadInstall) : localizationStore.L(L10n.Mods.updateMod))
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(modsStore.downloadingMods.contains(mod.name) ? Color.gray : Color.blue)
                        .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .pointingHandCursor()
                    .disabled(modsStore.downloadingMods.contains(mod.name))
                    .help(localizationStore.L(L10n.Mods.updateAvailable))
                }

                Button {
                    let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
                    let url = URL(fileURLWithPath: appEnvironment.gameDir)
                        .appendingPathComponent(baseFolder)
                        .appendingPathComponent(mod.folderName.rawValue)
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(localizationStore.L(L10n.Mods.openFolder))
                .pointingHandCursor()

                if hasConfigJson {
                    Button {
                        modsStore.editingModConfig = mod
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(localizationStore.L(L10n.Settings.configEditor))
                    .pointingHandCursor()
                }

                if !mod.nexusUrl.isEmpty || !mod.dependencies.isEmpty {
                    Button {
                        modsStore.viewingModDetails = mod
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(localizationStore.L(L10n.Settings.nexusModDetails))
                    .pointingHandCursor()
                }
            }
            .padding(.trailing, 8)

            // macOS Native Switch Toggle
            if !isChild {
                Toggle("", isOn: Binding(
                    get: { localIsOn ?? mod.isEnabled },
                    set: { newValue in
                        localIsOn = newValue
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(300))
                            if newValue != mod.isEnabled {
                                appCoordinator.toggleMod(mod)
                            }
                            localIsOn = nil
                        }
                    }
                ))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .controlSize(.small)
                    .labelsHidden()
            } else {
                Toggle("", isOn: .constant(false))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .controlSize(.small)
                    .labelsHidden()
                    .opacity(0)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.secondary.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier("mod-row-\(mod.folderName.rawValue)")
        .contextMenu {
            Menu {
                ForEach(["tag_nexus_2", "tag_nexus_3", "tag_nexus_4", "tag_nexus_5", "tag_nexus_6", "tag_nexus_7", "tag_nexus_8", "tag_nexus_9", "tag_nexus_10", "tag_nexus_11", "tag_nexus_12", "tag_nexus_13", "tag_nexus_14", "tag_nexus_15", "tag_nexus_16", "tag_nexus_17", "tag_nexus_18", "tag_nexus_19", "tag_nexus_20", "tag_nexus_21", "tag_nexus_22", "tag_nexus_23", "tag_nexus_24", "tag_nexus_25", "tag_nexus_26", "tag_nexus_27", "Content Patcher", "Translation", "Other"], id: \.self) { tag in
                    Button {
                        appCoordinator.setCustomTag(for: mod.uniqueId, tag: tag)
                    } label: {
                        HStack {
                            Text(localizationStore.localizedTag(tag))
                            if modsStore.customModTags[mod.uniqueId.rawValue] == tag {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if modsStore.customModTags[mod.uniqueId.rawValue] != nil {
                    Divider()
                    Button(role: .destructive) {
                        appCoordinator.resetCustomTag(for: mod.uniqueId)
                    } label: {
                        Text(localizationStore.L(L10n.Tags.reset))
                    }
                }
            } label: {
                Text(localizationStore.L(L10n.Tags.change))
            }

            Divider()

            Button(localizationStore.L(L10n.Mods.openInFinder)) {
                let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
                let url = URL(fileURLWithPath: appEnvironment.gameDir)
                    .appendingPathComponent(baseFolder)
                    .appendingPathComponent(mod.folderName.rawValue)
                NSWorkspace.shared.open(url)
            }
            if !mod.nexusUrl.isEmpty {
                Button(localizationStore.L(L10n.Mods.viewDetailsOnNexus)) {
                    if let url = URL(string: mod.nexusUrl) { NSWorkspace.shared.open(url) }
                }
                if !appEnvironment.nexusApiKey.isEmpty {
                    if let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                        Button(localizationStore.L(L10n.Settings.nexusEndorse)) {
                            Task {
                                do {
                                    try await modsStore.endorseMod(nexusId: nId, version: mod.version, apiKey: appEnvironment.nexusApiKey)
                                    alertStore.show(localizationStore.L(L10n.Settings.nexusEndorsed))
                                } catch {
                                    alertStore.show("Failed to endorse mod")
                                }
                            }
                        }
                    }
                }
            }
            if let update = pendingUpdate {
                Divider()
                Button(localizationStore.L(L10n.Mods.updateMod)) {
                    if let url = URL(string: update.url) { NSWorkspace.shared.open(url) }
                }
            }
        }
    }

    private var shortDateFormatter: DateFormatter {
        localizationStore.makeDateFormatter()
    }
}

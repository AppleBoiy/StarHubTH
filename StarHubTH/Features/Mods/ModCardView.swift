import SwiftUI

struct ModCardView: View {
    let mod: Mod
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    var isChild: Bool = false
    var isGroupHeader: Bool = false
    @Binding var isExpanded: Bool
    @State private var isHovered = false
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
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Title & Toggle
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(mod.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(!mod.isEnabled ? .secondary : .primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if hasMissingDependencies {
                            let names = mod.dependencies.filter { $0.isRequired && modsStore.resolveDependencyStatus(for: $0.uniqueId) != .active }.map { $0.uniqueId.rawValue }.joined(separator: ", ")
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .help(String(format: localizationStore.L(L10n.Mods.missingDependencies), names))
                        }
                    }

                    if mod.name != mod.folderName.rawValue {
                        Text(mod.folderName.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                // Group Expand Chevron OR Toggle
                if isGroupHeader {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                } else {
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
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .labelsHidden()
                    .scaleEffect(0.8)
                }
            }

            // Badges & Updates
            if !mod.tag.isEmpty && !isChild {
                Text(localizationStore.localizedTag(mod.tag))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
            }

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

            // Subtitle
            if !mod.isGroup {
                Text("\(mod.author) • v\(mod.version)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                let displayAuthor = localizationStore.L(mod.author)
                let countStr = Int(mod.description).map { String(format: localizationStore.L(L10n.Mods.groupCount), $0) } ?? mod.description
                Text("\(displayAuthor) • \(countStr)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            // Footer: Actions
            actionButtons
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isChild ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if let update = pendingUpdate {
                updateButton(update: update)
            }

            Spacer()

            folderButton

            if hasConfigJson {
                configButton
            }

            detailsButton
        }
    }

    private func updateButton(update: ModUpdateInfo) -> some View {
        Button {
            if !appEnvironment.nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                Task { await appCoordinator.downloadAndInstallUpdate(for: update, nexusId: Mod.NexusID(rawValue: nId)) }
            } else if let url = URL(string: update.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 14))
                .foregroundColor(modsStore.downloadingMods.contains(mod.name) ? .gray : .blue)
        }
        .buttonStyle(PlainButtonStyle())
        .pointingHandCursor()
        .disabled(modsStore.downloadingMods.contains(mod.name))
        .help(modsStore.downloadingMods.contains(mod.name) ? localizationStore.L(L10n.Settings.nexusDownloading) : localizationStore.L(L10n.Mods.updateMod))
    }

    private var folderButton: some View {
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
    }

    private var configButton: some View {
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

    private var detailsButton: some View {
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

    private var shortDateFormatter: DateFormatter {
        localizationStore.makeDateFormatter()
    }
}

import SwiftUI

struct ModListView: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var alertStore: AlertStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var searchText = ""
    @State private var isDropTargeted = false

    // ── Derived: all unique tags present in the loaded mods ──────────
    private var availableTags: [String] {
        var tags = Set<String>()
        for mod in modsStore.mods {
            if case .group(let children) = mod.kind {
                for c in children where !c.tag.isEmpty { tags.insert(c.tag) }
            } else if !mod.tag.isEmpty {
                tags.insert(mod.tag)
            }
        }
        return tags.sorted()
    }

    // ── Full filtering + sorting pipeline ────────────────────────────
    // Pipeline lives in ModListFilter (Features/Mods/ModListFilter.swift) so it is unit-tested.
    private var processedMods: [Mod] {
        ModListFilter(
            searchText: searchText,
            status: modsStore.modFilterStatus,
            tag: modsStore.modFilterTag,
            date: modsStore.modFilterDate,
            sort: modsStore.modSortOption
        )
        .apply(to: modsStore.mods)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Controls bar ──────────────────────────────────────────
            ModControlsBar(availableTags: availableTags)

            Divider()

            // ── Update banner (only when updates exist) ───────────────
            if !modsStore.outOfDateMods.isEmpty {
                ModUpdateBanner()
                Divider()
            }

            // ── List ──────────────────────────────────────────────────
            ZStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        if processedMods.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.5))
                                if modsStore.mods.isEmpty {
                                    Text(localizationStore.L(L10n.Mods.noModsInstalled))
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    // Empty-state install hint
                                    Button {
                                        Task { await appCoordinator.openInstallModPanel() }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text(localizationStore.L(L10n.Mods.installMod))
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .pointingHandCursor()
                                    .padding(.top, 4)
                                } else {
                                    Text(String(format: localizationStore.L(L10n.Mods.noModFound), searchText.isEmpty ? "-" : searchText))
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            // When status filter is "All" → split into enabled/disabled sections
                            // When status filter is set   → single section
                            if modsStore.modFilterStatus == .all {
                                let enabled  = processedMods.filter { $0.isEnabled }
                                let disabled = processedMods.filter { !$0.isEnabled }
                                if !enabled.isEmpty {
                                    ModSectionGroup(title: localizationStore.L(L10n.Mods.enabled), mods: enabled)
                                }
                                if !disabled.isEmpty {
                                    ModSectionGroup(title: localizationStore.L(L10n.Mods.disabled), mods: disabled)
                                }
                            } else {
                                let sectionTitle = modsStore.modFilterStatus == .enabled
                                    ? localizationStore.L(L10n.Mods.enabled)
                                    : localizationStore.L(L10n.Mods.disabled)
                                ModSectionGroup(title: sectionTitle, mods: processedMods)
                            }
                        }
                    }
                    .padding(24)
                }

                // ── Drop zone overlay ──────────────────────────────────
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 3, dash: [10, 6])
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                        .overlay(
                            VStack(spacing: 10) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                                Text(localizationStore.L(L10n.Mods.installDropHint))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        )
                        .padding(16)
                        .transition(.opacity)
                }

                // ── Installing spinner overlay ─────────────────────────
                if modsStore.isInstallingMod {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(localizationStore.L(L10n.Mods.installing))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .shadow(radius: 8)
                        )
                    }
                    .transition(.opacity)
                }
            }
            // ── Drop handler ───────────────────────────────────────────
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                var handled = false
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url = url else { return }
                        let ext = url.pathExtension.lowercased()
                        var isDir: ObjCBool = false
                        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                        guard ext == "zip" || isDir.boolValue else { return }
                        Task { @MainActor in await appCoordinator.installMod(url: url) }
                    }
                    handled = true
                }
                return handled
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .searchable(text: $searchText, prompt: Text(localizationStore.L(L10n.Mods.searchMods)))
        .toolbar {
            ToolbarItem {
                Button {
                    appCoordinator.scanMods()
                    if !appEnvironment.nexusApiKey.isEmpty {
                        Task { await appCoordinator.syncAllTagsFromNexus() }
                    }
                } label: {
                    if modsStore.isSyncingAllTags {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text("\(Int(modsStore.syncAllTagsProgress * 100))%")
                                .monospacedDigit()
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(localizationStore.L(L10n.Tags.sync))
                        }
                    }
                }
                .disabled(modsStore.isSyncingAllTags)
                .help(localizationStore.L(L10n.Tags.sync))
            }
        }
    }
}

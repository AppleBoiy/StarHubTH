import SwiftUI

// MARK: - ModListView

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
                for c in children where !c.modTag.isEmpty { tags.insert(c.modTag) }
            } else if !mod.modTag.isEmpty {
                tags.insert(mod.modTag)
            }
        }
        return tags.sorted()
    }

    // ── Full filtering + sorting pipeline ────────────────────────────
    // Pipeline lives in ModListFilter (Features/Mods/ModListFilter.swift) so it is unit-tested.
    private var processedMods: [ModItem] {
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

// MARK: - Controls Bar

struct ModControlsBar: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    let availableTags: [String]
    @AppStorage("modListViewMode") private var viewMode: String = "list"

    var body: some View {
        HStack(spacing: 10) {
            // Status filter pills
            StatusFilterPills()

            Spacer()

            // Type filter menu
            Menu {
                Button {
                    modsStore.modFilterTag = ""
                } label: {
                    HStack {
                        Text(localizationStore.L(L10n.Mods.filterTypeAll))
                        if modsStore.modFilterTag.isEmpty {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                if !availableTags.isEmpty { Divider() }
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        modsStore.modFilterTag = tag
                    } label: {
                        HStack {
                            Text(localizationStore.localizedTag(tag))
                            if modsStore.modFilterTag == tag {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 11))
                    Text(modsStore.modFilterTag.isEmpty ? localizationStore.L(L10n.Mods.filterTypeAll) : localizationStore.localizedTag(modsStore.modFilterTag))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(modsStore.modFilterTag.isEmpty ? .secondary : .accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(modsStore.modFilterTag.isEmpty
                              ? Color.primary.opacity(0.06)
                              : Color.accentColor.opacity(0.12))
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            // Date Filter menu
            Menu {
                ForEach([
                    (ModFilterDate.all,         L10n.Mods.filterDateAll),
                    (.past24Hours,              L10n.Mods.filterDate24h),
                    (.past7Days,                L10n.Mods.filterDate7d),
                    (.past30Days,               L10n.Mods.filterDate30d),
                ], id: \.0) { option, key in
                    Button {
                        modsStore.modFilterDate = option
                    } label: {
                        HStack {
                            Text(localizationStore.L(key))
                            if modsStore.modFilterDate == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(modsStore.modFilterDate == .all ? localizationStore.L(L10n.Mods.filterDateAll) :
                            (modsStore.modFilterDate == .past24Hours ? localizationStore.L(L10n.Mods.filterDate24h) :
                                (modsStore.modFilterDate == .past7Days ? localizationStore.L(L10n.Mods.filterDate7d) : localizationStore.L(L10n.Mods.filterDate30d))))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(modsStore.modFilterDate == .all ? .secondary : .accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(modsStore.modFilterDate == .all
                              ? Color.primary.opacity(0.06)
                              : Color.accentColor.opacity(0.12))
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            // Sort menu
            Menu {
                ForEach([
                    (ModSortOption.name,     L10n.Mods.sortName),
                    (.nameDesc,              L10n.Mods.sortNameDesc),
                    (.author,               L10n.Mods.sortAuthor),
                    (.version,              L10n.Mods.sortVersion),
                    (.dateAddedDesc,        L10n.Mods.sortDateAdded),
                    (.dateModifiedDesc,     L10n.Mods.sortDateModified),
                    (.status,               L10n.Mods.sortStatus),
                ], id: \.0) { option, key in
                    Button {
                        modsStore.modSortOption = option
                    } label: {
                        HStack {
                            Text(localizationStore.L(key))
                            if modsStore.modSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text(localizationStore.L(L10n.Mods.sortBy))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .menuStyle(BorderlessButtonMenuStyle())
            
            // View Mode Toggle
            Picker("", selection: $viewMode) {
                Image(systemName: "list.bullet").tag("list")
                Image(systemName: "square.grid.2x2").tag("grid")
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 70)
            .padding(.leading, 8)

            Divider()
                .frame(height: 18)

            // Install Mod button
            Button {
                Task { await appCoordinator.openInstallModPanel() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text(localizationStore.L(L10n.Mods.installMod))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .pointingHandCursor()
            .help(localizationStore.L(L10n.Mods.installDropHint))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Status Filter Pills

struct StatusFilterPills: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore

    private var options: [(ModFilterStatus, String)] {[
        (.all,      localizationStore.L(L10n.Mods.filterAll)),
        (.enabled,  localizationStore.L(L10n.Mods.filterEnabled)),
        (.disabled, localizationStore.L(L10n.Mods.filterDisabled)),
    ]}

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0.rawValue) { status, label in
                Button {
                    modsStore.modFilterStatus = status
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: modsStore.modFilterStatus == status ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .foregroundColor(modsStore.modFilterStatus == status ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(modsStore.modFilterStatus == status ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandCursor()
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Update Banner

struct ModUpdateBanner: View {
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var modsStore: ModsStore
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text(String(format: localizationStore.L(L10n.Mods.updateCount), Int64(modsStore.outOfDateMods.count)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .pointingHandCursor()
            .background(Color.blue.opacity(0.06))

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(modsStore.outOfDateMods) { update in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(update.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("→ \(update.version)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: update.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                    Text(localizationStore.L(L10n.Mods.updateMod))
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .cornerRadius(5)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .pointingHandCursor()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.03))

                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
    }
}

// MARK: - Section Group
struct ModSectionGroup: View {
    let title: String
    let mods: [ModItem]
    @AppStorage("modListViewMode") private var viewMode: String = "list"
    @State private var expandedGroups: [ModItem.FolderName: Bool] = [:]

    let columns = [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]

    var body: some View {
        StandardSection(title: title) {
            if viewMode == "grid" {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(mods, id: \.id) { mod in
                        if case .group(let children) = mod.kind {
                            ModCardView(mod: mod, isChild: false, isGroupHeader: true, isExpanded: Binding(
                                get: { expandedGroups[mod.id, default: false] },
                                set: { expandedGroups[mod.id] = $0 }
                            ))
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedGroups[mod.id, default: false].toggle()
                                }
                            }
                            
                            if expandedGroups[mod.id] == true {
                                ForEach(children, id: \.id) { child in
                                    ModCardView(mod: child, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
                                }
                            }
                        } else {
                            ModCardView(mod: mod, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mods.enumerated()), id: \.element.id) { idx, mod in
                        if case .group(let children) = mod.kind {
                            ModGroupRow(mod: mod, children: children)
                        } else {
                            ModListRow(mod: mod, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
                        }
                        
                        if idx < mods.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                                .padding(.leading, 48)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, -8)
            }
        }
    }
}

// MARK: - Mod Group Row
struct ModGroupRow: View {
    let mod: ModItem
    let children: [ModItem]
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            ModListRow(mod: mod, isChild: false, isGroupHeader: true, isExpanded: $isExpanded)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { cIdx, child in
                        ModListRow(mod: child, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
                        if cIdx < children.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                                .padding(.leading, 64)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Row
struct ModListRow: View {
    let mod: ModItem
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
                    if !mod.modTag.isEmpty && !isChild {
                        Text(localizationStore.localizedTag(mod.modTag))
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
                
                let missingDeps = modsStore.getMissingDependencies(for: mod)
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
                            Task { await appCoordinator.downloadAndInstallUpdate(for: update, nexusId: ModItem.NexusID(rawValue: nId)) }
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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

// MARK: - Grid Card Views

struct ModCardView: View {
    let mod: ModItem
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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
            if !mod.modTag.isEmpty && !isChild {
                Text(localizationStore.localizedTag(mod.modTag))
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
                Task { await appCoordinator.downloadAndInstallUpdate(for: update, nexusId: ModItem.NexusID(rawValue: nId)) }
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

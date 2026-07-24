import SwiftUI

// MARK: - ModListView

struct ModListView: View {
    @ObservedObject var vm: StarHubTHViewModel
    @State private var searchText = ""
    @State private var isDropTargeted = false

    // ── Derived: all unique tags present in the loaded mods ──────────
    private var availableTags: [String] {
        var tags = Set<String>()
        for mod in vm.mods {
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
            status: vm.modFilterStatus,
            tag: vm.modFilterTag,
            date: vm.modFilterDate,
            sort: vm.modSortOption
        )
        .apply(to: vm.mods)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Controls bar ──────────────────────────────────────────
            ModControlsBar(vm: vm, availableTags: availableTags)

            Divider()

            // ── Update banner (only when updates exist) ───────────────
            if !vm.outOfDateMods.isEmpty {
                ModUpdateBanner(vm: vm)
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
                                if vm.mods.isEmpty {
                                    Text(vm.L(L10n.Mods.noModsInstalled))
                                        .multilineTextAlignment(.center)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    // Empty-state install hint
                                    Button {
                                        vm.openInstallModPanel()
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text(vm.L(L10n.Mods.installMod))
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
                                    Text(String(format: vm.L(L10n.Mods.noModFound), searchText.isEmpty ? "-" : searchText))
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
                            if vm.modFilterStatus == .all {
                                let enabled  = processedMods.filter { $0.isEnabled }
                                let disabled = processedMods.filter { !$0.isEnabled }
                                if !enabled.isEmpty {
                                    ModSectionGroup(title: vm.L(L10n.Mods.enabled), mods: enabled, vm: vm)
                                }
                                if !disabled.isEmpty {
                                    ModSectionGroup(title: vm.L(L10n.Mods.disabled), mods: disabled, vm: vm)
                                }
                            } else {
                                let sectionTitle = vm.modFilterStatus == .enabled
                                    ? vm.L(L10n.Mods.enabled)
                                    : vm.L(L10n.Mods.disabled)
                                ModSectionGroup(title: sectionTitle, mods: processedMods, vm: vm)
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
                                Text(vm.L(L10n.Mods.installDropHint))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                        )
                        .padding(16)
                        .transition(.opacity)
                }

                // ── Installing spinner overlay ─────────────────────────
                if vm.isInstallingMod {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text(vm.L(L10n.Mods.installing))
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
                        DispatchQueue.main.async { vm.installMod(url: url) }
                    }
                    handled = true
                }
                return handled
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .searchable(text: $searchText, prompt: Text(vm.L(L10n.Mods.searchMods)))
        .toolbar {
            ToolbarItem {
                Button {
                    vm.scanMods()
                    if !vm.nexusApiKey.isEmpty {
                        vm.syncAllTagsFromNexus()
                    }
                } label: {
                    if vm.isSyncingAllTags {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                            Text("\(Int(vm.syncAllTagsProgress * 100))%")
                                .monospacedDigit()
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(vm.L(L10n.Tags.sync))
                        }
                    }
                }
                .disabled(vm.isSyncingAllTags)
                .help(vm.L(L10n.Tags.sync))
            }
        }
    }
}

// MARK: - Controls Bar

struct ModControlsBar: View {
    @ObservedObject var vm: StarHubTHViewModel
    let availableTags: [String]
    @AppStorage("modListViewMode") private var viewMode: String = "list"

    var body: some View {
        HStack(spacing: 10) {
            // Status filter pills
            StatusFilterPills(vm: vm)

            Spacer()

            // Type filter menu
            Menu {
                Button {
                    vm.modFilterTag = ""
                } label: {
                    HStack {
                        Text(vm.L(L10n.Mods.filterTypeAll))
                        if vm.modFilterTag.isEmpty {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                if !availableTags.isEmpty { Divider() }
                ForEach(availableTags, id: \.self) { tag in
                    Button {
                        vm.modFilterTag = tag
                    } label: {
                        HStack {
                            Text(vm.localizedTag(tag))
                            if vm.modFilterTag == tag {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 11))
                    Text(vm.modFilterTag.isEmpty ? vm.L(L10n.Mods.filterTypeAll) : vm.localizedTag(vm.modFilterTag))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(vm.modFilterTag.isEmpty ? .secondary : .accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(vm.modFilterTag.isEmpty
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
                        vm.modFilterDate = option
                    } label: {
                        HStack {
                            Text(vm.L(key))
                            if vm.modFilterDate == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(vm.modFilterDate == .all ? vm.L(L10n.Mods.filterDateAll) :
                            (vm.modFilterDate == .past24Hours ? vm.L(L10n.Mods.filterDate24h) :
                                (vm.modFilterDate == .past7Days ? vm.L(L10n.Mods.filterDate7d) : vm.L(L10n.Mods.filterDate30d))))
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(vm.modFilterDate == .all ? .secondary : .accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(vm.modFilterDate == .all
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
                        vm.modSortOption = option
                    } label: {
                        HStack {
                            Text(vm.L(key))
                            if vm.modSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 11))
                    Text(vm.L(L10n.Mods.sortBy))
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
                vm.openInstallModPanel()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12))
                    Text(vm.L(L10n.Mods.installMod))
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
            .help(vm.L(L10n.Mods.installDropHint))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Status Filter Pills

struct StatusFilterPills: View {
    @ObservedObject var vm: StarHubTHViewModel

    private var options: [(ModFilterStatus, String)] {[
        (.all,      vm.L(L10n.Mods.filterAll)),
        (.enabled,  vm.L(L10n.Mods.filterEnabled)),
        (.disabled, vm.L(L10n.Mods.filterDisabled)),
    ]}

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0.rawValue) { status, label in
                Button {
                    vm.modFilterStatus = status
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: vm.modFilterStatus == status ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: true)
                        .foregroundColor(vm.modFilterStatus == status ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(vm.modFilterStatus == status ? Color.accentColor : Color.clear)
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
    @ObservedObject var vm: StarHubTHViewModel
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
                    Text(String(format: vm.L(L10n.Mods.updateCount), Int64(vm.outOfDateMods.count)))
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
                    ForEach(vm.outOfDateMods) { update in
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
                                    Text(vm.L(L10n.Mods.updateMod))
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
    @ObservedObject var vm: StarHubTHViewModel
    @AppStorage("modListViewMode") private var viewMode: String = "list"
    @State private var expandedGroups: [String: Bool] = [:]

    let columns = [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]

    var body: some View {
        StandardSection(title: title) {
            if viewMode == "grid" {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(mods, id: \.id) { mod in
                        if case .group(let children) = mod.kind {
                            ModCardView(mod: mod, vm: vm, isChild: false, isGroupHeader: true, isExpanded: Binding(
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
                                    ModCardView(mod: child, vm: vm, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
                                }
                            }
                        } else {
                            ModCardView(mod: mod, vm: vm, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mods.enumerated()), id: \.element.id) { idx, mod in
                        if case .group(let children) = mod.kind {
                            ModGroupRow(mod: mod, children: children, vm: vm)
                        } else {
                            ModListRow(mod: mod, vm: vm, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
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
    @ObservedObject var vm: StarHubTHViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            ModListRow(mod: mod, vm: vm, isChild: false, isGroupHeader: true, isExpanded: $isExpanded)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(children.enumerated()), id: \.element.id) { cIdx, child in
                        ModListRow(mod: child, vm: vm, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
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
    @ObservedObject var vm: StarHubTHViewModel
    @State private var isHovered = false
    var isChild: Bool = false
    var isGroupHeader: Bool = false
    @Binding var isExpanded: Bool
    @State private var localIsOn: Bool?
    
    private var hasConfigJson: Bool {
        guard !mod.isGroup else { return false }
        let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
        let path = URL(fileURLWithPath: vm.gameDir)
            .appendingPathComponent(baseFolder)
            .appendingPathComponent(mod.folderName)
            .appendingPathComponent("config.json")
            .path
        return FileManager.default.fileExists(atPath: path)
    }

    /// Returns a matching ModUpdateInfo if this mod has an update available
    private var pendingUpdate: ModUpdateInfo? {
        guard !mod.isGroup else { return nil }
        return vm.outOfDateMods.first {
            $0.name.localizedCaseInsensitiveCompare(mod.name) == .orderedSame ||
            mod.name.lowercased().contains($0.name.lowercased())
        }
    }
    
    private var hasMissingDependencies: Bool {
        guard mod.isEnabled && !mod.isGroup else { return false }
        for dep in mod.dependencies where dep.isRequired {
            if vm.resolveDependencyStatus(for: dep.uniqueId) != .active {
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
                        let names = mod.dependencies.filter { $0.isRequired && vm.resolveDependencyStatus(for: $0.uniqueId) != .active }.map(\.uniqueId).joined(separator: ", ")
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .help(String(format: vm.L(L10n.Mods.missingDependencies), names))
                    }

                    // Type tag badge
                    if !mod.modTag.isEmpty && !isChild {
                        Text(vm.localizedTag(mod.modTag))
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
                            Text(vm.L(L10n.Mods.updateAvailable))
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                    }
                }
                
                if mod.name != mod.folderName {
                    Text(mod.folderName)
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
                    let displayAuthor = vm.L(mod.author)
                    let countStr = Int(mod.description).map { String(format: vm.L(L10n.Mods.groupCount), $0) } ?? mod.description
                    Text("\(displayAuthor) • \(countStr)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                let missingDeps = vm.getMissingDependencies(for: mod)
                if !missingDeps.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: vm.L(L10n.Mods.missingDependencies), missingDeps.joined(separator: ", ")))
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
                        if !vm.nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                            vm.downloadAndInstallUpdate(for: update, nexusId: nId)
                        } else if let url = URL(string: update.url) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if vm.downloadingMods.contains(mod.name) {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                                Text(vm.L(L10n.Settings.nexusDownloading))
                                    .font(.system(size: 11, weight: .medium))
                            } else {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 11))
                                Text(!vm.nexusApiKey.isEmpty ? vm.L(L10n.Settings.nexusDownloadInstall) : vm.L(L10n.Mods.updateMod))
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(vm.downloadingMods.contains(mod.name) ? Color.gray : Color.blue)
                        .cornerRadius(5)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .pointingHandCursor()
                    .disabled(vm.downloadingMods.contains(mod.name))
                    .help(vm.L(L10n.Mods.updateAvailable))
                }

                Button {
                    let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
                    let url = URL(fileURLWithPath: vm.gameDir)
                        .appendingPathComponent(baseFolder)
                        .appendingPathComponent(mod.folderName)
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(vm.L(L10n.Mods.openFolder))
                .pointingHandCursor()
                
                if hasConfigJson {
                    Button {
                        vm.editingModConfig = mod
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(vm.L(L10n.Settings.configEditor))
                    .pointingHandCursor()
                }
                
                if !mod.nexusUrl.isEmpty || !mod.dependencies.isEmpty {
                    Button {
                        vm.viewingModDetails = mod
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(vm.L(L10n.Settings.nexusModDetails))
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
                                vm.toggleMod(mod)
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
                        vm.setCustomTag(for: mod.uniqueId, tag: tag)
                    } label: {
                        HStack {
                            Text(vm.localizedTag(tag))
                            if vm.customModTags[mod.uniqueId] == tag {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                if vm.customModTags[mod.uniqueId] != nil {
                    Divider()
                    Button(role: .destructive) {
                        vm.resetCustomTag(for: mod.uniqueId)
                    } label: {
                        Text(vm.L(L10n.Tags.reset))
                    }
                }
            } label: {
                Text(vm.L(L10n.Tags.change))
            }
            
            Divider()
            
            Button(vm.L(L10n.Mods.openInFinder)) {
                let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
                let url = URL(fileURLWithPath: vm.gameDir)
                    .appendingPathComponent(baseFolder)
                    .appendingPathComponent(mod.folderName)
                NSWorkspace.shared.open(url)
            }
            if !mod.nexusUrl.isEmpty {
                Button(vm.L(L10n.Mods.viewDetailsOnNexus)) {
                    if let url = URL(string: mod.nexusUrl) { NSWorkspace.shared.open(url) }
                }
                if !vm.nexusApiKey.isEmpty {
                    if let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                        Button(vm.L(L10n.Settings.nexusEndorse)) {
                            NexusAPIService.shared.endorseMod(modId: nId, version: mod.version, apiKey: vm.nexusApiKey) { result in
                                DispatchQueue.main.async {
                                    if case .success = result {
                                        vm.showModal(message: vm.L(L10n.Settings.nexusEndorsed))
                                    } else {
                                        vm.showModal(message: "Failed to endorse mod")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if let update = pendingUpdate {
                Divider()
                Button(vm.L(L10n.Mods.updateMod)) {
                    if let url = URL(string: update.url) { NSWorkspace.shared.open(url) }
                }
            }
        }
    }
    
    private var shortDateFormatter: DateFormatter {
        vm.makeDateFormatter()
    }
}

// MARK: - Grid Card Views

struct ModCardView: View {
    let mod: ModItem
    @ObservedObject var vm: StarHubTHViewModel
    var isChild: Bool = false
    var isGroupHeader: Bool = false
    @Binding var isExpanded: Bool
    @State private var isHovered = false
    @State private var localIsOn: Bool?

    private var hasConfigJson: Bool {
        guard !mod.isGroup else { return false }
        let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
        let path = URL(fileURLWithPath: vm.gameDir)
            .appendingPathComponent(baseFolder)
            .appendingPathComponent(mod.folderName)
            .appendingPathComponent("config.json")
            .path
        return FileManager.default.fileExists(atPath: path)
    }

    private var pendingUpdate: ModUpdateInfo? {
        guard !mod.isGroup else { return nil }
        return vm.outOfDateMods.first {
            $0.name.localizedCaseInsensitiveCompare(mod.name) == .orderedSame ||
            mod.name.lowercased().contains($0.name.lowercased())
        }
    }
    
    private var hasMissingDependencies: Bool {
        guard mod.isEnabled && !mod.isGroup else { return false }
        for dep in mod.dependencies where dep.isRequired {
            if vm.resolveDependencyStatus(for: dep.uniqueId) != .active {
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
                            let names = mod.dependencies.filter { $0.isRequired && vm.resolveDependencyStatus(for: $0.uniqueId) != .active }.map(\.uniqueId).joined(separator: ", ")
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .help(String(format: vm.L(L10n.Mods.missingDependencies), names))
                        }
                    }
                    
                    if mod.name != mod.folderName {
                        Text(mod.folderName)
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
                                    vm.toggleMod(mod)
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
                Text(vm.localizedTag(mod.modTag))
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
                    Text(vm.L(L10n.Mods.updateAvailable))
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
                let displayAuthor = vm.L(mod.author)
                let countStr = Int(mod.description).map { String(format: vm.L(L10n.Mods.groupCount), $0) } ?? mod.description
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
            if !vm.nexusApiKey.isEmpty, let url = URL(string: mod.nexusUrl), let nId = Int(url.lastPathComponent) {
                vm.downloadAndInstallUpdate(for: update, nexusId: nId)
            } else if let url = URL(string: update.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 14))
                .foregroundColor(vm.downloadingMods.contains(mod.name) ? .gray : .blue)
        }
        .buttonStyle(PlainButtonStyle())
        .pointingHandCursor()
        .disabled(vm.downloadingMods.contains(mod.name))
        .help(vm.downloadingMods.contains(mod.name) ? vm.L(L10n.Settings.nexusDownloading) : vm.L(L10n.Mods.updateMod))
    }

    private var folderButton: some View {
        Button {
            let baseFolder = mod.isEnabled ? "Mods" : "Mods_disabled"
            let url = URL(fileURLWithPath: vm.gameDir)
                .appendingPathComponent(baseFolder)
                .appendingPathComponent(mod.folderName)
            NSWorkspace.shared.open(url)
        } label: {
            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .help(vm.L(L10n.Mods.openFolder))
        .pointingHandCursor()
    }

    private var configButton: some View {
        Button {
            vm.editingModConfig = mod
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .help(vm.L(L10n.Settings.configEditor))
        .pointingHandCursor()
    }

    private var detailsButton: some View {
        Button {
            vm.viewingModDetails = mod
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .help(vm.L(L10n.Settings.nexusModDetails))
        .pointingHandCursor()
    }
    
    private var shortDateFormatter: DateFormatter {
        vm.makeDateFormatter()
    }
}

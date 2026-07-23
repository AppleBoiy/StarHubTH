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
            if mod.isGroup, let children = mod.children {
                for c in children where !c.modTag.isEmpty { tags.insert(c.modTag) }
            } else if !mod.modTag.isEmpty {
                tags.insert(mod.modTag)
            }
        }
        return tags.sorted()
    }

    // ── Full filtering + sorting pipeline ────────────────────────────
    private var processedMods: [ModItem] {
        let lowerSearch = searchText.lowercased()

        return vm.mods
            // 1. Search
            .filter { mod in
                guard !lowerSearch.isEmpty else { return true }
                if mod.name.lowercased().contains(lowerSearch) { return true }
                if mod.uniqueId.lowercased().contains(lowerSearch) { return true }
                if mod.author.lowercased().contains(lowerSearch) { return true }
                if mod.isGroup, let children = mod.children {
                    return children.contains {
                        $0.name.lowercased().contains(lowerSearch) ||
                        $0.uniqueId.lowercased().contains(lowerSearch)
                    }
                }
                return false
            }
            // 2. Status filter
            .filter { mod in
                switch vm.modFilterStatus {
                case .all:      return true
                case .enabled:  return mod.isEnabled
                case .disabled: return !mod.isEnabled
                }
            }
            // 3. Type tag filter
            .filter { mod in
                guard !vm.modFilterTag.isEmpty else { return true }
                if mod.isGroup, let children = mod.children {
                    return children.contains { $0.modTag == vm.modFilterTag }
                }
                return mod.modTag == vm.modFilterTag
            }
            // 4. Sort
            .sorted { a, b in
                // Groups always float to the top
                if a.isGroup != b.isGroup { return a.isGroup }
                switch vm.modSortOption {
                case .name:     return a.name.lowercased() < b.name.lowercased()
                case .nameDesc: return a.name.lowercased() > b.name.lowercased()
                case .author:   return a.author.lowercased() < b.author.lowercased()
                case .version:  return a.version.lowercased() < b.version.lowercased()
                case .status:
                    if a.isEnabled != b.isEnabled { return a.isEnabled }
                    return a.name.lowercased() < b.name.lowercased()
                }
            }
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
    }
}

// MARK: - Controls Bar

struct ModControlsBar: View {
    @ObservedObject var vm: StarHubTHViewModel
    let availableTags: [String]

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
                            Text(tag)
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
                    Text(vm.modFilterTag.isEmpty ? vm.L(L10n.Mods.filterTypeAll) : vm.modFilterTag)
                        .font(.system(size: 12))
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

            // Sort menu
            Menu {
                ForEach([
                    (ModSortOption.name,     L10n.Mods.sortName),
                    (.nameDesc,              L10n.Mods.sortNameDesc),
                    (.author,               L10n.Mods.sortAuthor),
                    (.version,              L10n.Mods.sortVersion),
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

    var body: some View {
        StandardSection(title: title) {
            VStack(spacing: 0) {
                ForEach(Array(mods.enumerated()), id: \.element.id) { idx, mod in
                    if mod.isGroup, let children = mod.children {
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
    @State private var isShowingDependencies = false
    @State private var isShowingDetails = false
    
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
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // Type tag badge
                    if !mod.modTag.isEmpty && !isChild {
                        Text(mod.modTag)
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
                    Text(mod.description)
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
                        if !vm.nexusApiKey.isEmpty {
                            isShowingDetails = true
                        } else {
                            isShowingDependencies = true
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(!vm.nexusApiKey.isEmpty ? vm.L(L10n.Settings.nexusModDetails) : vm.L(L10n.Mods.viewOnNexus))
                    .pointingHandCursor()
                    .popover(isPresented: $isShowingDependencies, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            if !mod.nexusUrl.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Nexus Mods")
                                        .font(.headline)
                                    Button {
                                        if let url = URL(string: mod.nexusUrl) { NSWorkspace.shared.open(url) }
                                    } label: {
                                        HStack {
                                            Image(systemName: "link")
                                            Text(vm.L(L10n.Mods.viewOnNexus))
                                        }
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .pointingHandCursor()
                                }
                            }
                            
                            if !mod.dependencies.isEmpty {
                                if !mod.nexusUrl.isEmpty {
                                    Divider()
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(vm.L(L10n.Profiles.dependencies))
                                        .font(.headline)
                                    
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ForEach(mod.dependencies, id: \.uniqueId) { dep in
                                                let targetMod = vm.mods.first(where: { $0.uniqueId.caseInsensitiveCompare(dep.uniqueId) == .orderedSame })
                                                let isInstalled = targetMod != nil
                                                let isEnabled = targetMod?.isEnabled ?? false
                                                
                                                HStack {
                                                    if isEnabled {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                            .font(.system(size: 10))
                                                    } else if isInstalled {
                                                        Image(systemName: "exclamationmark.circle.fill")
                                                            .foregroundColor(.orange)
                                                            .font(.system(size: 10))
                                                    } else {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .foregroundColor(.red.opacity(0.5))
                                                            .font(.system(size: 10))
                                                    }
                                                    
                                                    Text(dep.uniqueId)
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundColor(isEnabled ? .primary : .secondary)
                                                    Spacer()
                                                    if dep.isRequired {
                                                        Text(vm.L(L10n.Profiles.required))
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundColor(.red)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.red.opacity(0.1))
                                                            .cornerRadius(4)
                                                    } else {
                                                        Text(vm.L(L10n.Profiles.optional))
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.secondary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.secondary.opacity(0.1))
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(width: 300)
                        .frame(maxHeight: 300)
                    }
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
        .background(
            vm.selectedModID == mod.folderName
                ? Color.accentColor.opacity(0.08)
                : Color.clear
        )
        .cornerRadius(6)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu {
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
        .sheet(isPresented: $isShowingDetails) {
            ModDetailView(vm: vm, mod: mod)
        }
    }
}

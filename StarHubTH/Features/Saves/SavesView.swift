import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - SaveAvatarView (shared avatar renderer)
struct SaveAvatarView: View {
    let folderName: String
    let size: CGFloat
    @EnvironmentObject var savesStore: SavesStore
    
    private let presets: [(String, String)] = [
        ("preset:person", "person.crop.circle.fill"),
        ("preset:star", "star.fill"),
        ("preset:leaf", "leaf.fill"),
        ("preset:heart", "heart.fill"),
        ("preset:cat", "cat.fill"),
        ("preset:dog", "dog.fill"),
        ("preset:hare", "hare.fill"),
        ("preset:ant", "ant.fill"),
    ]
    
    var body: some View {
        let iconPath = savesStore.getNote(for: folderName).customIconPath ?? ""
        
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
            
            if iconPath.hasPrefix("preset:") {
                let sfName = presets.first(where: { $0.0 == iconPath })?.1 ?? "person.crop.circle.fill"
                Image(systemName: sfName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .padding(size * 0.18)
            } else if !iconPath.isEmpty, let img = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SaveAvatarViewLocal (iconPath from local @State, no vm needed)
struct SaveAvatarViewLocal: View {
    let iconPath: String
    let size: CGFloat
    
    private let presets: [(String, String)] = [
        ("preset:person", "person.crop.circle.fill"),
        ("preset:star", "star.fill"),
        ("preset:leaf", "leaf.fill"),
        ("preset:heart", "heart.fill"),
        ("preset:cat", "cat.fill"),
        ("preset:dog", "dog.fill"),
        ("preset:hare", "hare.fill"),
        ("preset:ant", "ant.fill"),
    ]
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))
            
            if iconPath.hasPrefix("preset:") {
                let sfName = presets.first(where: { $0.0 == iconPath })?.1 ?? "person.crop.circle.fill"
                Image(systemName: sfName)
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .padding(size * 0.18)
            } else if !iconPath.isEmpty, let img = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .frame(width: size * 0.8, height: size * 0.8)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - SavesView
struct SavesView: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @State private var searchText = ""

    var filteredSaves: [SaveGameInfo] {
        savesStore.saves.filter { save in
            let searchMatch = searchText.isEmpty ||
                save.playerName.localizedCaseInsensitiveContains(searchText) ||
                save.farmName.localizedCaseInsensitiveContains(searchText)
            let tagMatch = savesStore.saveFilterTag.isEmpty ||
                savesStore.getNote(for: save.folderName).tag == savesStore.saveFilterTag
            return searchMatch && tagMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Finder-like Toolbar
            HStack(spacing: 8) {
                // View mode toggle
                HStack(spacing: 2) {
                    Button(action: { withAnimation { savesStore.saveViewMode = .list } }) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12, weight: .medium))
                            .padding(5)
                            .background(savesStore.saveViewMode == .list ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(savesStore.saveViewMode == .list ? .accentColor : .secondary)

                    Button(action: { withAnimation { savesStore.saveViewMode = .grid } }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12, weight: .medium))
                            .padding(5)
                            .background(savesStore.saveViewMode == .grid ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(savesStore.saveViewMode == .grid ? .accentColor : .secondary)
                }
                .padding(2)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(7)
                
                Divider().frame(height: 20)
                
                // Sort
                Menu {
                    Button(action: { savesStore.saveSortOption = .lastPlayed }) {
                        HStack { Image(systemName: "clock"); Text(localizationStore.L(L10n.Saves.sortLastPlayed)) }
                        if savesStore.saveSortOption == .lastPlayed { Image(systemName: "checkmark") }
                    }
                    Button(action: { savesStore.saveSortOption = .name }) {
                        HStack {
                            if localizationStore.currentLanguage == "th" {
                                Image(systemName: "character.textbox.th") // Icon ก ในช่องสี่เหลี่ยม
                            } else {
                                Image(systemName: "a.square")
                            }
                            Text(localizationStore.L(L10n.Saves.sortName))
                        }
                        if savesStore.saveSortOption == .name { Image(systemName: "checkmark") }
                    }
                    Button(action: { savesStore.saveSortOption = .money }) {
                        HStack { Image(systemName: "dollarsign"); Text(localizationStore.L(L10n.Saves.sortMoney)) }
                        if savesStore.saveSortOption == .money { Image(systemName: "checkmark") }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(sortLabel)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                // Tag Filter
                Menu {
                    Button(action: { savesStore.saveFilterTag = "" }) {
                        HStack { Image(systemName: "tray.2"); Text(localizationStore.L(L10n.Saves.filterAll)) }
                        if savesStore.saveFilterTag.isEmpty { Image(systemName: "checkmark") }
                    }
                    Divider()
                    ForEach(savesStore.availableFilterTags, id: \.self) { tag in
                        Button(action: { savesStore.saveFilterTag = (savesStore.saveFilterTag == tag ? "" : tag) }) {
                            Text("\(tag) \(tag)")
                            if savesStore.saveFilterTag == tag { Image(systemName: "checkmark") }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: savesStore.saveFilterTag.isEmpty ? "tag" : "tag.fill")
                            .font(.system(size: 11))
                        Text(savesStore.saveFilterTag.isEmpty ? localizationStore.L(L10n.Saves.filterTag) : savesStore.saveFilterTag)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(savesStore.saveFilterTag.isEmpty ? .secondary : .accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(savesStore.saveFilterTag.isEmpty ? Color(nsColor: .controlBackgroundColor) : Color.accentColor.opacity(0.12))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                
                Spacer()
                
                Button(action: { savesStore.reloadSaves() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // MARK: Content
            if savesStore.saves.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "cloud.bolt")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(localizationStore.L(L10n.Saves.noSaves))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else if savesStore.saveViewMode == .grid {
                SavesGridView(saves: filteredSaves)
            } else {
                Form {
                    Section {
                        if searchText.isEmpty {
                            SaveTreeListView(nodes: savesStore.savesHierarchy, depth: 0)
                        } else {
                            ForEach(filteredSaves, id: \.id) { save in
                                Button(action: { savesStore.editingSave = save }) {
                                    SaveRow(save: save, depth: 0, hasChildren: false, isExpanded: false, onToggleExpand: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(String(format: localizationStore.L(L10n.Saves.allSaves), Int64(searchText.isEmpty ? savesStore.savesHierarchy.count : filteredSaves.count)))
                    } footer: {
                        Text(localizationStore.L(L10n.Saves.autoFetch))
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .searchable(text: $searchText, prompt: Text(localizationStore.L(L10n.Main.search)))
        .toolbar {
            ToolbarItem {
                Button {
                    savesStore.reloadSaves()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(localizationStore.L(L10n.Tags.sync))
                    }
                }
                .help(localizationStore.L(L10n.Tags.sync))
            }
        }
        .sheet(item: $savesStore.saveToDuplicate) { save in
            DuplicateSaveSheet(save: save)
        }
    }
    
    var sortLabel: String {
        switch savesStore.saveSortOption {
        case .name:       return localizationStore.L(L10n.Saves.sortLabelName)
        case .lastPlayed: return localizationStore.L(L10n.Saves.sortLabelLastPlayed)
        case .money:      return localizationStore.L(L10n.Saves.sortLabelMoney)
        }
    }
}

// MARK: - Grid View
struct SavesGridView: View {
    let saves: [SaveGameInfo]
    let columns = [GridItem(.adaptive(minimum: 130, maximum: 170), spacing: 16)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(saves) { save in
                    SaveCardView(save: save)
                }
            }
            .padding(20)
        }
    }
}

struct SaveCardView: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let save: SaveGameInfo
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { savesStore.editingSave = save }) {
            VStack(spacing: 10) {
                SaveAvatarView(folderName: save.folderName, size: 64)
                
                VStack(spacing: 2) {
                    let note = savesStore.getNote(for: save.folderName)
                    HStack(spacing: 4) {
                        if !note.tag.isEmpty {
                            Text(note.tag).font(.system(size: 13))
                        }
                        Text(save.playerName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                    }
                    Text(save.farmName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(String(format: localizationStore.L(L10n.Saves.yearDayFormat), save.year, localizationStore.L(save.seasonName), save.day))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(localizationStore.L(L10n.Saves.edit)) { savesStore.editingSave = save }
            Button(localizationStore.L(L10n.Saves.timeline)) { savesStore.viewingSaveTimeline = save }
            Divider()
            Button(localizationStore.L(L10n.Saves.duplicate)) { savesStore.saveToDuplicate = save }
            Button(localizationStore.L(L10n.Saves.openFolder)) { savesStore.openSaveInFinder(info: save) }
            Divider()
            Button(localizationStore.L(L10n.Saves.deleteSave), role: .destructive) { appCoordinator.deleteSave(info: save) }
        }
    }
}

// MARK: - Tree List View
struct SaveTreeListView: View {
    @EnvironmentObject var savesStore: SavesStore
    let nodes: [SaveNode]
    let depth: Int
    @State private var expandedSaves: Set<String> = []

    var body: some View {
        ForEach(nodes) { node in
            let hasChildren = !node.children.isEmpty
            let isExpanded = expandedSaves.contains(node.info.folderName)

            Button(action: { savesStore.editingSave = node.info }) {
                SaveRow(
                    save: node.info,
                    depth: depth,
                    hasChildren: hasChildren,
                    isExpanded: isExpanded,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedSaves.remove(node.info.folderName)
                            } else {
                                expandedSaves.insert(node.info.folderName)
                            }
                        }
                    }
                )
            }
            .buttonStyle(.plain)
            
            if hasChildren && isExpanded {
                SaveTreeListView(nodes: node.children, depth: depth + 1)
            }
        }
    }
}

// MARK: - Save Row (List)
struct SaveRow: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let save: SaveGameInfo
    let depth: Int
    
    var hasChildren: Bool = false
    var isExpanded: Bool = false
    var onToggleExpand: (() -> Void)? = nil
    
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if depth > 0 {
                HStack(spacing: 4) {
                    Spacer().frame(width: CGFloat(depth) * 16 - 8)
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundColor(.secondary.opacity(0.5))
                        .font(.system(size: 10))
                }
            }
            
            // Expand/Collapse Chevron
            if hasChildren {
                Button(action: { onToggleExpand?() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 32)
            }
            
            SaveAvatarView(folderName: save.folderName, size: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                let note = savesStore.getNote(for: save.folderName)
                HStack(spacing: 6) {
                    if !note.tag.isEmpty {
                        Text(note.tag)
                            .font(.system(size: 14))
                    }
                    Text(save.playerName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
                let format = localizationStore.L(L10n.Saves.farmFormat)
                let moneyStr = NumberFormatter.localizedString(from: NSNumber(value: save.money), number: .decimal)
                let formattedStr = String(format: format, save.farmName, save.year, localizationStore.L(save.seasonName), save.day, moneyStr)
                Text(formattedStr)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                let earnedStr = NumberFormatter.localizedString(from: NSNumber(value: save.totalMoneyEarned), number: .decimal)
                Text("\(localizationStore.L(L10n.Saves.totalMoneyEarned)): \(earnedStr)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            
            Spacer()
            
            Menu {
                Button(action: { savesStore.editingSave = save }) {
                    Label(localizationStore.L(L10n.Saves.saveManagement), systemImage: "pencil")
                }
                Button(action: { savesStore.viewingSaveTimeline = save }) {
                    Label(localizationStore.L(L10n.Saves.timeline), systemImage: "clock.arrow.circlepath")
                }
                Divider()
                Button(action: { savesStore.openSaveInFinder(info: save) }) {
                    Label(localizationStore.L(L10n.Saves.openFolder), systemImage: "folder")
                }
                Button(action: { savesStore.saveToDuplicate = save }) {
                    Label(localizationStore.L(L10n.Saves.duplicate), systemImage: "doc.on.doc")
                }
                Divider()
                Button(role: .destructive, action: { appCoordinator.deleteSave(info: save) }) {
                    Label(localizationStore.L(L10n.Saves.deleteSave), systemImage: "trash")
                }
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                    .padding(.trailing, 4)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 30)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Editor View
struct SaveEditorView: View {
    @EnvironmentObject var savesStore: SavesStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let save: SaveGameInfo
    
    @State private var name: String
    @State private var farm: String
    @State private var fav: String
    @State private var moneyStr: String
    @State private var maxHealthStr: String
    @State private var maxStaminaStr: String
    @State private var goldenWalnutsStr: String
    @State private var qiGemsStr: String
    @State private var clubCoinsStr: String
    @State private var totalMoneyEarnedStr: String
    @State private var spouse: String   // empty = single
    
    /// All NPC names that can be married in Stardew Valley (vanilla)
    static let marriableNPCs: [String] = [
        "Abigail", "Alex", "Elliott", "Emily", "Harvey",
        "Haley", "Leah", "Maru", "Penny", "Sam",
        "Sebastian", "Shane"
    ]
    
    @State private var noteTag: String
    @State private var noteText: String
    @State private var iconPath: String
    
    let availableTags = ["", "⭐", "🏆", "🧪", "❤️", "💎", "📅"]
    
    let presetIcons: [(String, String, String)] = [
        ("preset:person", "person.crop.circle.fill", "Default"),
        ("preset:star",   "star.fill",               "Star"),
        ("preset:leaf",   "leaf.fill",               "Leaf"),
        ("preset:heart",  "heart.fill",              "Heart"),
        ("preset:cat",    "cat.fill",                "Cat"),
        ("preset:dog",    "dog.fill",                "Dog"),
        ("preset:hare",   "hare.fill",               "Rabbit"),
        ("preset:ant",    "ant.fill",                "Ant"),
    ]
    
    /// `noteTag`/`noteText`/`iconPath` can't be seeded from `savesStore` here — as an
    /// `@EnvironmentObject`, it isn't available until the view is placed in the
    /// hierarchy, unlike the old `vm:` init parameter. They default empty and get their
    /// real values in `.onAppear` instead.
    init(save: SaveGameInfo) {
        self.save = save
        _name = State(initialValue: save.playerName)
        _farm = State(initialValue: save.farmName)
        _fav = State(initialValue: save.favoriteThing)
        _moneyStr = State(initialValue: "\(save.money)")
        _maxHealthStr = State(initialValue: "\(save.maxHealth)")
        _maxStaminaStr = State(initialValue: "\(save.maxStamina)")
        _goldenWalnutsStr = State(initialValue: "\(save.goldenWalnuts)")
        _qiGemsStr = State(initialValue: "\(save.qiGems)")
        _clubCoinsStr = State(initialValue: "\(save.clubCoins)")
        _totalMoneyEarnedStr = State(initialValue: "\(save.totalMoneyEarned)")
        _spouse = State(initialValue: save.spouse)

        _noteTag = State(initialValue: "")
        _noteText = State(initialValue: "")
        _iconPath = State(initialValue: "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(save.playerName)
                    .font(.headline)
                Spacer()
                Button(action: { savesStore.viewingSaveTimeline = save }) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text(localizationStore.L(L10n.Saves.timeline))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.trailing, 8)
                
                Button(action: { savesStore.editingSave = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()

            // Form
            Form {
                // MARK: Avatar Section
                Section(localizationStore.L(L10n.Saves.avatarSection)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            SaveAvatarViewLocal(iconPath: iconPath, size: 56)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(localizationStore.L(L10n.Saves.avatarPreset))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 8), spacing: 6) {
                                    ForEach(presetIcons, id: \.0) { (key, sfName, label) in
                                        Button(action: {
                                            iconPath = key
                                            savesStore.setAvatar(forSave: save.folderName, iconPath: key)
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(iconPath == key ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: sfName)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(iconPath == key ? .accentColor : .secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .help(label)
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(localizationStore.L(L10n.Saves.avatarPickFile)) {
                                savesStore.selectCustomAvatar(forSave: save.folderName) { path in
                                    iconPath = path
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            if !iconPath.isEmpty {
                                Button(localizationStore.L(L10n.Saves.avatarReset)) {
                                    iconPath = ""
                                    savesStore.setAvatar(forSave: save.folderName, iconPath: "")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                
                Section(localizationStore.L(L10n.Saves.notes)) {
                    Picker(localizationStore.L(L10n.Saves.tag), selection: $noteTag) {
                        ForEach(availableTags, id: \.self) { tag in
                            Text(tag.isEmpty ? "None" : tag).tag(tag)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField(localizationStore.L(L10n.Saves.saveNote), text: $noteText)
                }
                
                Section(localizationStore.L(L10n.Saves.characterInfo)) {
                    TextField(localizationStore.L(L10n.Saves.characterName), text: $name)
                    TextField(localizationStore.L(L10n.Saves.farmName), text: $farm)
                    TextField(localizationStore.L(L10n.Saves.favoriteThing), text: $fav)
                }
                
                // MARK: Relationship Section
                Section(localizationStore.L(L10n.Saves.relationshipSection)) {
                    Picker(localizationStore.L(L10n.Saves.spouseLabel), selection: $spouse) {
                        Text(localizationStore.L(L10n.Saves.spouseNone)).tag("")
                        ForEach(SaveEditorView.marriableNPCs, id: \.self) { npc in
                            Text(npc).tag(npc)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show warning only when changing away from existing spouse
                    if !save.spouse.isEmpty && spouse != save.spouse {
                        Text(localizationStore.L(L10n.Saves.spouseWarning))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section(localizationStore.L(L10n.Saves.resources)) {
                    TextField(localizationStore.L(L10n.Saves.money), text: $moneyStr)
                    TextField(localizationStore.L(L10n.Saves.totalMoneyEarned), text: $totalMoneyEarnedStr)
                    TextField(localizationStore.L(L10n.Saves.casinoCoins), text: $clubCoinsStr)
                    TextField(localizationStore.L(L10n.Saves.goldenWalnuts), text: $goldenWalnutsStr)
                    TextField(localizationStore.L(L10n.Saves.qiGems), text: $qiGemsStr)
                }
                
                Section(localizationStore.L(L10n.Saves.characterStats)) {
                    TextField(localizationStore.L(L10n.Saves.maxHealth), text: $maxHealthStr)
                    TextField(localizationStore.L(L10n.Saves.maxStamina), text: $maxStaminaStr)
                }
                
                Section(localizationStore.L(L10n.Saves.inventoryEditor)) {
                    ForEach(savesStore.inventoryToEdit.indices, id: \.self) { index in
                        let item = savesStore.inventoryToEdit[index]
                        if item.isObject {
                            HStack {
                                Text("\(item.name)")
                                    .frame(width: 150, alignment: .leading)
                                Text("ID: \(item.itemId)")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(localizationStore.L(L10n.Saves.itemQuantity))
                                TextField("", value: $savesStore.inventoryToEdit[index].stack, formatter: NumberFormatter())
                                    .frame(width: 60)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button(action: {
                                    savesStore.inventoryToEdit[index] = InventoryItem.empty(slot: index)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                        } else if !item.name.isEmpty {
                            HStack {
                                Text("\(item.name)")
                                    .frame(width: 150, alignment: .leading)
                                if !item.itemId.isEmpty {
                                    Text("ID: \(item.itemId)")
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(localizationStore.L(L10n.Saves.nonObject))
                                    .foregroundColor(.secondary)
                                    
                                Button(action: {
                                    savesStore.inventoryToEdit[index] = InventoryItem.empty(slot: index)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                        }
                    }
                    
                    Button(localizationStore.L(L10n.Saves.saveInventory)) {
                        appCoordinator.saveInventory()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
                }
                
                Section(localizationStore.L(L10n.Saves.saveManagement)) {
                    HStack {
                        Button(localizationStore.L(L10n.Saves.openFolder)) { savesStore.openSaveInFinder(info: save) }
                        Button(localizationStore.L(L10n.Saves.duplicate)) { savesStore.saveToDuplicate = save; savesStore.editingSave = nil }
                        Spacer()
                        Button(localizationStore.L(L10n.Saves.deleteSave)) { appCoordinator.deleteSave(info: save); savesStore.editingSave = nil }
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            Divider()
            
            // Footer
            HStack {
                Text(localizationStore.L(L10n.Saves.backupNote))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                
                Button(localizationStore.L(L10n.Saves.saveChanges)) {
                    let newMoney = Int(moneyStr) ?? save.money
                    let newTotalMoneyEarned = Int(totalMoneyEarnedStr) ?? save.totalMoneyEarned
                    let newHealth = Int(maxHealthStr) ?? save.maxHealth
                    let newStam = Int(maxStaminaStr) ?? save.maxStamina
                    let newWalnuts = Int(goldenWalnutsStr) ?? save.goldenWalnuts
                    let newQi = Int(qiGemsStr) ?? save.qiGems
                    let newClub = Int(clubCoinsStr) ?? save.clubCoins
                    
                    savesStore.setNote(for: save.folderName, tag: noteTag, note: noteText)
                    appCoordinator.editSave(info: save, newName: name, newFarm: farm, newFav: fav, newMoney: newMoney, newTotalMoneyEarned: newTotalMoneyEarned, newMaxHealth: newHealth, newMaxStamina: newStam, newGoldenWalnuts: newWalnuts, newQiGems: newQi, newClubCoins: newClub, newSpouse: spouse)
                    savesStore.editingSave = nil
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(BorderedProminentButtonStyle())
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            let note = savesStore.getNote(for: save.folderName)
            noteTag = note.tag
            noteText = note.note
            iconPath = note.customIconPath ?? ""
        }
    }
}

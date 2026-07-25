import SwiftUI

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

                    savesStore.setNote(noteText, tag: noteTag, forSave: save.folderName)
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
            let note = savesStore.note(for: save.folderName)
            noteTag = note.tag
            noteText = note.note
            iconPath = note.customIconPath ?? ""
        }
    }
}

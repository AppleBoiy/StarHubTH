import SwiftUI

struct SavesView: View {
    @ObservedObject var vm: StarHubTHViewModel
    @State private var searchText = ""

    var filteredSaves: [SaveGameInfo] {
        if searchText.isEmpty {
            return vm.saves
        } else {
            return vm.saves.filter {
                $0.playerName.localizedCaseInsensitiveContains(searchText) ||
                $0.farmName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        Form {
            Section {
                if vm.saves.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cloud.bolt")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(vm.L(L10n.Saves.noSaves))
                            .multilineTextAlignment(.center)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(filteredSaves, id: \.id) { save in
                        Button(action: { vm.editingSave = save }) {
                            SaveRow(vm: vm, save: save)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text(String(format: vm.L(L10n.Saves.allSaves), Int64(filteredSaves.count)))
                    Spacer()
                    Button(action: { vm.reloadSaves() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            } footer: {
                Text(vm.L(L10n.Saves.autoFetch))
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .controlBackgroundColor))
        .searchable(text: $searchText, prompt: Text(vm.L(L10n.Main.search)))
    }
}

// MARK: - Save Row
struct SaveRow: View {
    @ObservedObject var vm: StarHubTHViewModel
    let save: SaveGameInfo
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(Color.accentColor.opacity(0.8))
                    .frame(width: 32, height: 32)
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(save.playerName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                let format = vm.L(L10n.Saves.farmFormat)
                let moneyStr = NumberFormatter.localizedString(from: NSNumber(value: save.money), number: .decimal)
                let formattedStr = String(format: format, save.farmName, save.year, vm.L(save.seasonName), save.day, moneyStr)
                Text(formattedStr)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
                .padding(.trailing, 4)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Editor View
struct SaveEditorView: View {
    @ObservedObject var vm: StarHubTHViewModel
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
    
    init(vm: StarHubTHViewModel, save: SaveGameInfo) {
        self.vm = vm
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
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(save.playerName)
                    .font(.headline)
                Spacer()
                Button(action: { vm.editingSave = nil }) {
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
                Section(vm.L(L10n.Saves.characterInfo)) {
                    TextField(vm.L(L10n.Saves.characterName), text: $name)
                    TextField(vm.L(L10n.Saves.farmName), text: $farm)
                    TextField(vm.L(L10n.Saves.favoriteThing), text: $fav)
                }
                
                Section(vm.L(L10n.Saves.resources)) {
                    TextField(vm.L(L10n.Saves.money), text: $moneyStr)
                    TextField(vm.L(L10n.Saves.casinoCoins), text: $clubCoinsStr)
                    TextField(vm.L(L10n.Saves.goldenWalnuts), text: $goldenWalnutsStr)
                    TextField(vm.L(L10n.Saves.qiGems), text: $qiGemsStr)
                }
                
                Section(vm.L(L10n.Saves.characterStats)) {
                    TextField(vm.L(L10n.Saves.maxHealth), text: $maxHealthStr)
                    TextField(vm.L(L10n.Saves.maxStamina), text: $maxStaminaStr)
                }
                
                Section(vm.L(L10n.Saves.saveManagement)) {
                    HStack {
                        Button(vm.L(L10n.Saves.openFolder)) { vm.openSaveInFinder(info: save) }
                        Button(vm.L(L10n.Saves.duplicate)) { vm.duplicateSave(info: save); vm.editingSave = nil }
                        Spacer()
                        Button(vm.L(L10n.Saves.deleteSave)) { vm.deleteSave(info: save); vm.editingSave = nil }
                            .foregroundColor(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            Divider()
            
            // Footer
            HStack {
                Text(vm.L(L10n.Saves.backupNote))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                
                Button(vm.L(L10n.Saves.saveChanges)) {
                    let newMoney = Int(moneyStr) ?? save.money
                    let newHealth = Int(maxHealthStr) ?? save.maxHealth
                    let newStam = Int(maxStaminaStr) ?? save.maxStamina
                    let newWalnuts = Int(goldenWalnutsStr) ?? save.goldenWalnuts
                    let newQi = Int(qiGemsStr) ?? save.qiGems
                    let newClub = Int(clubCoinsStr) ?? save.clubCoins
                    
                    vm.editSave(info: save, newName: name, newFarm: farm, newFav: fav, newMoney: newMoney, newMaxHealth: newHealth, newMaxStamina: newStam, newGoldenWalnuts: newWalnuts, newQiGems: newQi, newClubCoins: newClub)
                    vm.editingSave = nil
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(BorderedProminentButtonStyle())
            }
            .padding(20)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

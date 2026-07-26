import SwiftUI

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
                savesStore.note(for: save.folderName).tag == savesStore.saveFilterTag
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
                    .accessibilityIdentifier("saves-view-mode-list")

                    Button(action: { withAnimation { savesStore.saveViewMode = .grid } }) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12, weight: .medium))
                            .padding(5)
                            .background(savesStore.saveViewMode == .grid ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(savesStore.saveViewMode == .grid ? .accentColor : .secondary)
                    .accessibilityIdentifier("saves-view-mode-grid")
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

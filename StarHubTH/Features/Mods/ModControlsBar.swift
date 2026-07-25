import SwiftUI

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

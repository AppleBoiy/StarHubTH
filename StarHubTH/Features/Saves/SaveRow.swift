import SwiftUI

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
                let note = savesStore.note(for: save.folderName)
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

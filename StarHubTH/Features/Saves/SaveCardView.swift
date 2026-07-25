import SwiftUI

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
                    let note = savesStore.note(for: save.folderName)
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

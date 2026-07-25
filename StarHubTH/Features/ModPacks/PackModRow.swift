import SwiftUI

struct PackModRow: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var localizationStore: LocalizationStore
    let packMod: StarHubPackMod

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Thumbnail
            Group {
                if let thumbStr = packMod.thumbnailUrl, let thumbUrl = URL(string: thumbStr) {
                    AsyncImage(url: thumbUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            modPlaceholder
                        }
                    }
                } else {
                    modPlaceholder
                }
            }
            .frame(width: 36, height: 36)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))

            // Left: Name + meta row
            VStack(alignment: .leading, spacing: 3) {
                Text(packMod.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                // Meta row
                HStack(spacing: 8) {
                    if let author = packMod.modAuthor, !author.isEmpty {
                        metaBit(icon: "person.fill", text: author)
                    }
                    if let nexusId = packMod.nexusId {
                        metaBit(icon: "number", text: "#\(nexusId)")
                    }
                    if let downloads = packMod.modDownloads {
                        metaBit(icon: "arrow.down.circle", text: formatCount(downloads))
                    }
                    if let updated = packMod.modUpdatedAt, !updated.isEmpty {
                        metaBit(icon: "clock", text: updated)
                    }
                    if let version = packMod.version, !version.isEmpty {
                        metaBit(icon: "tag", text: "v\(version)")
                    }
                }
            }

            Spacer()

            // Status badge + action
            let status = modsStore.resolvePackModStatus(nexusId: packMod.nexusId, uniqueId: packMod.uniqueId)

            HStack(spacing: 8) {
                switch status {
                case .installed:
                    Label(localizationStore.L(L10n.ModPacks.installed), systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12, weight: .medium))
                case .disabled:
                    Label(localizationStore.L(L10n.ModPacksExtra.disabled), systemImage: "pause.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12, weight: .medium))
                case .missing:
                    Label(localizationStore.L(L10n.ModPacks.missing), systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12, weight: .medium))

                    if let nexusId = packMod.nexusId {
                        Button {
                            if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(nexusId)?tab=files") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text(localizationStore.L(L10n.ModPacks.getFromNexus))
                                .font(.system(size: 12))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var modPlaceholder: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private func metaBit(icon: String, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundColor(.secondary)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

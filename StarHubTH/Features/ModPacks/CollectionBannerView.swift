import SwiftUI

struct CollectionBannerView: View {
    @EnvironmentObject var modPacksStore: ModPacksStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var appCoordinator: AppCoordinator
    @EnvironmentObject var alertStore: AlertStore
    let pack: StarHubPack
    @State private var isDownloadingAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Top section: cover + info ──────────────────────────────
            HStack(alignment: .top, spacing: 14) {
                // Cover art
                Group {
                    if let imageUrlStr = pack.imageUrl, let imageUrl = URL(string: imageUrlStr) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                coverPlaceholder
                            case .empty:
                                coverPlaceholder.overlay(ProgressView().scaleEffect(0.6))
                            @unknown default:
                                coverPlaceholder
                            }
                        }
                    } else {
                        coverPlaceholder
                    }
                }
                .frame(width: 88, height: 88)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                // Title, author, stats, description
                VStack(alignment: .leading, spacing: 5) {
                    Text(pack.packName)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        if let author = pack.author {
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(author)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let endorsements = pack.endorsements {
                            HStack(spacing: 3) {
                                Image(systemName: "hand.thumbsup")
                                    .font(.system(size: 10))
                                Text(formatCount(endorsements))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                        if let downloads = pack.totalDownloads {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 10))
                                Text(formatCount(downloads))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    if let desc = pack.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                // Dismiss
                Button(action: { withAnimation { modPacksStore.importedModPack = nil } }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            // ── Bottom strip: metadata + action ───────────────────────
            Divider()

            HStack(spacing: 16) {
                if let revision = pack.revision {
                    metaChip(icon: "tag", label: "Revision \(revision)")
                }
                if let gameVersion = pack.gameVersion {
                    metaChip(icon: "gamecontroller", label: "Game \(gameVersion)")
                }
                if let updatedAt = pack.updatedAt {
                    metaChip(icon: "clock", label: "Updated \(updatedAt)")
                }

                Spacer()

                // Download All action
                if !appEnvironment.nexusApiKey.isEmpty {
                    Button {
                        isDownloadingAll = true
                        Task {
                            let (installed, failed) = await appCoordinator.downloadAllMissingPackMods(pack)
                            isDownloadingAll = false
                            appCoordinator.scanMods()
                            let message: String
                            if failed > 0 {
                                message = String(format: localizationStore.L(L10n.ModPacks.downloadAllSummaryWithFailures), installed, failed)
                            } else {
                                message = String(format: localizationStore.L(L10n.ModPacks.downloadAllSummary), installed)
                            }
                            alertStore.show(message)
                        }
                    } label: {
                        if isDownloadingAll {
                            Label(localizationStore.L(L10n.ModPacks.downloading), systemImage: "arrow.down.circle.fill")
                        } else {
                            Label(localizationStore.L(L10n.ModPacks.downloadAll), systemImage: "arrow.down.circle.fill")
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .cornerRadius(7)
                    .buttonStyle(.plain)
                    .disabled(isDownloadingAll)
                } else {
                    Text(localizationStore.L(L10n.ModPacksExtra.addApiKeyHint))
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
    }

    // MARK: - Helpers

    private var coverPlaceholder: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))
        }
    }

    private func metaChip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11))
        }
        .foregroundColor(.secondary)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fk", Double(n) / 1_000) }
        return "\(n)"
    }
}

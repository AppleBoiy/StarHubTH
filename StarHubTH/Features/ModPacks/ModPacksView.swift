import SwiftUI
import UniformTypeIdentifiers

struct ModPacksView: View {
    @ObservedObject var vm: StarHubTHViewModel
    @State private var isHoveringDrop = false
    @State private var collectionURL = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            if let pack = vm.importedModPack {
                // ── Rich Collection Banner ──────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    CollectionBannerView(vm: vm, pack: pack)
                    
                    Divider()
                    
                    // Mod list — ScrollView for even separators
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(pack.mods.enumerated()), id: \.element.id) { index, packMod in
                                PackModRow(vm: vm, packMod: packMod)
                                if index < pack.mods.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            } else {
                // Drop Zone
                VStack(spacing: 20) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 60))
                        .foregroundColor(isHoveringDrop ? .accentColor : .secondary)
                    
                    Text(vm.L(L10n.ModPacks.importHint))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(vm.L(L10n.ModPacksExtra.enterCollectionURL))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack {
                        TextField("https://next.nexusmods.com/stardewvalley/collections/...", text: $collectionURL)
                            .textFieldStyle(.roundedBorder)
                        Button("Import") {
                            guard !collectionURL.isEmpty else { return }
                            vm.importCollectionFromURL(collectionURL) { pack in
                                if let p = pack {
                                    withAnimation { self.vm.importedModPack = p }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 400)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isHoveringDrop ? Color.accentColor.opacity(0.1) : Color(nsColor: .textBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHoveringDrop ? Color.accentColor : Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 2, dash: [8]))
                )
                .onDrop(of: [.json], isTargeted: $isHoveringDrop) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadItem(forTypeIdentifier: UTType.json.identifier, options: nil) { item, error in
                        guard let url = item as? URL,
                              let pack = vm.importModPack(from: url) else { return }
                        DispatchQueue.main.async {
                            withAnimation { self.vm.importedModPack = pack }
                        }
                    }
                    return true
                }
            }
        }
        .padding()
    }
}

// MARK: - Rich Collection Banner

struct CollectionBannerView: View {
    @ObservedObject var vm: StarHubTHViewModel
    let pack: StarHubPack
    
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
                Button(action: { withAnimation { vm.importedModPack = nil } }) {
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
                if !vm.nexusApiKey.isEmpty {
                    Button {
                        for packMod in pack.mods {
                            let status = vm.resolvePackModStatus(nexusId: packMod.nexusId, uniqueId: packMod.uniqueId)
                            if status == .missing, let nexusId = packMod.nexusId {
                                vm.downloadModFromNexus(nexusId: nexusId) { success in
                                    if success { vm.scanMods() }
                                }
                            }
                        }
                    } label: {
                        Label(vm.L(L10n.ModPacks.downloadAll), systemImage: "arrow.down.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(vm.L(L10n.ModPacksExtra.addApiKeyHint))
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

// MARK: - Mod Row

struct PackModRow: View {
    @ObservedObject var vm: StarHubTHViewModel
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
            let status = vm.resolvePackModStatus(nexusId: packMod.nexusId, uniqueId: packMod.uniqueId)
            
            HStack(spacing: 8) {
                switch status {
                case .installed:
                    Label(vm.L(L10n.ModPacks.installed), systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12, weight: .medium))
                case .disabled:
                    Label(vm.L(L10n.ModPacksExtra.disabled), systemImage: "pause.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12, weight: .medium))
                case .missing:
                    Label(vm.L(L10n.ModPacks.missing), systemImage: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12, weight: .medium))
                    
                    if let nexusId = packMod.nexusId {
                        Button {
                            if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(nexusId)?tab=files") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text(vm.L(L10n.ModPacks.getFromNexus))
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

import SwiftUI
import UniformTypeIdentifiers

struct ModPacksView: View {
    @EnvironmentObject var modPacksStore: ModPacksStore
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    @State private var isHoveringDrop = false
    @State private var collectionURL = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            if let pack = modPacksStore.importedModPack {
                // ── Rich Collection Banner ──────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    CollectionBannerView(pack: pack)
                    
                    Divider()
                    
                    // Mod list — ScrollView for even separators
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(pack.mods.enumerated()), id: \.element.id) { index, packMod in
                                PackModRow(packMod: packMod)
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
                    
                    Text(localizationStore.L(L10n.ModPacks.importHint))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(localizationStore.L(L10n.ModPacksExtra.enterCollectionURL))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                    
                    HStack {
                        TextField("https://next.nexusmods.com/stardewvalley/collections/...", text: $collectionURL)
                            .textFieldStyle(.roundedBorder)
                        Button("Import") {
                            guard !collectionURL.isEmpty else { return }
                            Task {
                                if let pack = await appCoordinator.importCollectionFromURL(collectionURL) {
                                    withAnimation { self.modPacksStore.importedModPack = pack }
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
                        guard let url = item as? URL else { return }
                        Task { @MainActor in
                            guard let pack = modPacksStore.importModPack(from: url) else { return }
                            withAnimation { modPacksStore.importedModPack = pack }
                        }
                    }
                    return true
                }
            }
        }
        .padding()
    }
}

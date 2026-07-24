import SwiftUI
import UniformTypeIdentifiers

struct ModPacksView: View {
    @ObservedObject var vm: StarHubTHViewModel
    @State private var isHoveringDrop = false
    @State private var collectionURL = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header
            HStack {
                Text(vm.L(L10n.ModPacks.title))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    let name = vm.modProfiles.first { $0.id == vm.activeProfileId }?.name ?? "My Pack"
                    if let _ = vm.exportModPack(name: name) {
                        vm.showModal(message: "Mod Pack Exported Successfully")
                    }
                } label: {
                    Label(vm.L(L10n.ModPacks.exportPack), systemImage: "square.and.arrow.up")
                }
            }
            .padding(.top, 10)
            
            if let pack = vm.importedModPack {
                // Imported Pack View
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(vm.L(L10n.ModPacks.packName)): \(pack.packName)")
                            .font(.headline)
                        if let author = pack.author {
                            Text("by \(author)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(role: .cancel) {
                            withAnimation { vm.importedModPack = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !vm.nexusApiKey.isEmpty {
                        Button {
                            for packMod in pack.mods {
                                let isInstalled = vm.resolveDependencyStatus(for: packMod.uniqueId) != .missing
                                if !isInstalled, let nexusId = packMod.nexusId {
                                    vm.downloadModFromNexus(nexusId: nexusId) { success in
                                        if success {
                                            vm.scanMods()
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label(vm.L(L10n.ModPacks.downloadAll), systemImage: "arrow.down.circle.fill")
                        }
                    } else {
                        Text("Please use 'Get from Nexus' manually for each missing mod (Premium API Key not found).")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    List(pack.mods) { packMod in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(packMod.name).font(.system(size: 14, weight: .medium))
                                Text(packMod.uniqueId).font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            let isInstalled = vm.resolveDependencyStatus(for: packMod.uniqueId) != .missing
                            
                            if isInstalled {
                                Label(vm.L(L10n.ModPacks.installed), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Label(vm.L(L10n.ModPacks.missing), systemImage: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                
                                if let nexusId = packMod.nexusId {
                                    Button {
                                        if let url = URL(string: "https://www.nexusmods.com/stardewvalley/mods/\(nexusId)?tab=files") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    } label: {
                                        Text(vm.L(L10n.ModPacks.getFromNexus))
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                }
            } else {
                // Drop Zone
                VStack(spacing: 20) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 60))
                        .foregroundColor(isHoveringDrop ? .accentColor : .secondary)
                    
                    Text(vm.L(L10n.ModPacks.importHint))
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Or enter a Nexus Collection URL:")
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

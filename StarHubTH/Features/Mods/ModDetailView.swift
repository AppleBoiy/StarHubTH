import SwiftUI

struct ModDetailView: View {
    @EnvironmentObject var modsStore: ModsStore
    @EnvironmentObject var appEnvironment: AppEnvironment
    @EnvironmentObject var localizationStore: LocalizationStore
    @EnvironmentObject var appCoordinator: AppCoordinator
    let mod: Mod

    @State private var selectedTab: Int
    @State private var coverUrl: URL? = nil
    @State private var nexusDescription: [LiveNexusAPIClient.DescriptionBlock]? = nil
    @State private var nexusChangelog: [LiveNexusAPIClient.DescriptionBlock]? = nil
    @State private var isLoading: Bool = false

    @Environment(\.presentationMode) var presentationMode

    init(mod: Mod, initialTab: Int = 0) {
        self.mod = mod
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var localChangelog: String? {
        let basePath = (appEnvironment.gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modPath = (basePath as NSString).appendingPathComponent(mod.folderName.rawValue)
        let mdPath = (modPath as NSString).appendingPathComponent("CHANGELOG.md")
        let txtPath = (modPath as NSString).appendingPathComponent("changelog.txt")
        
        if FileManager.default.fileExists(atPath: mdPath) {
            return try? String(contentsOfFile: mdPath, encoding: .utf8)
        } else if FileManager.default.fileExists(atPath: txtPath) {
            return try? String(contentsOfFile: txtPath, encoding: .utf8)
        }
        return nil
    }
    
    var nexusId: Int? {
        guard let url = URL(string: mod.nexusUrl) else { return nil }
        return Int(url.lastPathComponent)
    }
    
    private var shortDateFormatter: DateFormatter {
        localizationStore.makeDateFormatter()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    if let coverUrl = coverUrl {
                        AsyncImage(url: coverUrl) { image in
                            image.resizable()
                                 .aspectRatio(contentMode: .fill)
                                 .frame(width: 64, height: 64)
                                 .clipShape(RoundedRectangle(cornerRadius: 10))
                        } placeholder: {
                            ProgressView().frame(width: 64, height: 64)
                        }
                        .accessibilityIdentifier("mod-detail-cover-image")
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mod.name)
                            .font(.system(size: 22, weight: .bold))
                            
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("v\(mod.version) • \(localizationStore.L(mod.author))")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Text("ID: \(mod.uniqueId.rawValue)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .textSelection(.enabled)
                                    
                                    if !mod.nexusUrl.isEmpty, let url = URL(string: mod.nexusUrl) {
                                        Text("•")
                                            .foregroundColor(.secondary.opacity(0.5))
                                            
                                        if let nId = nexusId {
                                            Link("Nexus (\(String(nId)))", destination: url)
                                                .font(.system(size: 11))
                                                .foregroundColor(.blue)
                                        } else {
                                            Link("Nexus", destination: url)
                                                .font(.system(size: 11))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                
                                // Dates
                                HStack(spacing: 8) {
                                    if let added = mod.installDate {
                                        Text("\(localizationStore.L(L10n.Mods.sortDateAdded)): \(shortDateFormatter.string(from: added))")
                                    }
                                    if let modified = mod.lastModifiedDate, modified != mod.installDate {
                                        if mod.installDate != nil {
                                            Text("•")
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                        Text("\(localizationStore.L(L10n.Mods.sortDateModified)): \(shortDateFormatter.string(from: modified))")
                                    }
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.8))
                            }
                                
                            if isLoading {
                                ProgressView().controlSize(.small)
                                    .padding(.leading, 4)
                            }
                        }
                    }
                    
                    Spacer()
                }
                
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading) {
                    if selectedTab == 0 {
                        if let blocks = nexusDescription {
                            BBCodeView(blocks: blocks)
                                .accessibilityIdentifier("mod-detail-description")
                        } else {
                            Text(.init(mod.description))
                                .font(.body)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("mod-detail-description")
                        }
                    } else if selectedTab == 1 {
                        if let blocks = nexusChangelog {
                            BBCodeView(blocks: blocks)
                        } else if let locLog = localChangelog {
                            Text(.init(locLog))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(localizationStore.L(L10n.Settings.nexusNoChangelog))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } else if selectedTab == 2 {
                        if mod.dependencies.isEmpty {
                            Text(localizationStore.L(L10n.VM.noDependenciesFound))
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            DependencyGraphView(mod: mod)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            
            Divider()
            
            // Footer
            VStack {
                Picker("", selection: $selectedTab) {
                    Text(localizationStore.L(L10n.Settings.nexusDescription)).tag(0)
                    Text(localizationStore.L(L10n.Settings.nexusChangelog)).tag(1)
                    Text(localizationStore.L(L10n.Profiles.dependencies)).tag(2)
                }
                .accessibilityIdentifier("mod-detail-tab-picker")
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if nexusId != nil && !appEnvironment.nexusApiKey.isEmpty {
                    Button {
                        isLoading = true
                        Task {
                            await appCoordinator.syncTagFromNexus(for: mod)
                            isLoading = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(localizationStore.L(L10n.Tags.sync))
                        }
                        .help(localizationStore.L(L10n.Tags.sync))
                    }
                    .accessibilityIdentifier("mod-detail-sync-button")
                }
                
                if !mod.nexusUrl.isEmpty {
                    Button {
                        if let url = URL(string: mod.nexusUrl) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("Nexus")
                        }
                        .help("Open on Nexus Mods")
                    }
                }
            }
        }
        .onAppear { Task { await loadNexusInfo() } }
    }

    private func loadNexusInfo() async {
        let apiKey = appEnvironment.nexusApiKey
        guard !apiKey.isEmpty, let nId = nexusId else { return }

        isLoading = true
        let (coverUrl, description, changelog) = await modsStore.fetchNexusInfo(nexusId: nId, apiKey: apiKey)
        self.coverUrl = coverUrl
        if let description { self.nexusDescription = description }
        if let changelog { self.nexusChangelog = changelog }
        self.isLoading = false
    }
}

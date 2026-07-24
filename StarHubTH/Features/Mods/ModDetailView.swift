import SwiftUI

struct ModDetailView: View {
    @ObservedObject var vm: StarHubTHViewModel
    let mod: ModItem
    
    @State private var selectedTab: Int
    @State private var coverUrl: URL? = nil
    @State private var nexusDescription: [LiveNexusAPIClient.DescriptionBlock]? = nil
    @State private var nexusChangelog: [LiveNexusAPIClient.DescriptionBlock]? = nil
    @State private var isLoading: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    
    init(vm: StarHubTHViewModel, mod: ModItem, initialTab: Int = 0) {
        self.vm = vm
        self.mod = mod
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var localChangelog: String? {
        let basePath = (vm.gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
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
        vm.makeDateFormatter()
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
                                Text("v\(mod.version) • \(vm.L(mod.author))")
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
                                        Text("\(vm.L(L10n.Mods.sortDateAdded)): \(shortDateFormatter.string(from: added))")
                                    }
                                    if let modified = mod.lastModifiedDate, modified != mod.installDate {
                                        if mod.installDate != nil {
                                            Text("•")
                                                .foregroundColor(.secondary.opacity(0.5))
                                        }
                                        Text("\(vm.L(L10n.Mods.sortDateModified)): \(shortDateFormatter.string(from: modified))")
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
                            BBCodeView(vm: vm, blocks: blocks)
                        } else {
                            Text(.init(mod.description))
                                .font(.body)
                                .textSelection(.enabled)
                        }
                    } else if selectedTab == 1 {
                        if let blocks = nexusChangelog {
                            BBCodeView(vm: vm, blocks: blocks)
                        } else if let locLog = localChangelog {
                            Text(.init(locLog))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(vm.L(L10n.Settings.nexusNoChangelog))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } else if selectedTab == 2 {
                        if mod.dependencies.isEmpty {
                            Text(vm.L(L10n.VM.noDependenciesFound))
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            DependencyGraphView(mod: mod, vm: vm)
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
                    Text(vm.L(L10n.Settings.nexusDescription)).tag(0)
                    Text(vm.L(L10n.Settings.nexusChangelog)).tag(1)
                    Text(vm.L(L10n.Profiles.dependencies)).tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if nexusId != nil && !vm.nexusApiKey.isEmpty {
                    Button {
                        isLoading = true
                        vm.syncTagFromNexus(for: mod) { success in
                            isLoading = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(vm.L(L10n.Tags.sync))
                        }
                        .help(vm.L(L10n.Tags.sync))
                    }
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
        .onAppear(perform: loadNexusInfo)
    }
    
    private func loadNexusInfo() {
        let apiKey = vm.nexusApiKey
        guard !apiKey.isEmpty, let nId = nexusId else { return }
        
        isLoading = true
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        LiveNexusAPIClient.shared.getModInfo(modId: nId, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                if case .success(let info) = result {
                    if let pic = info.pictureUrl {
                        self.coverUrl = URL(string: pic)
                    }
                    self.nexusDescription = LiveNexusAPIClient.parseBlocks(info.description)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.enter()
        LiveNexusAPIClient.shared.getModFiles(modId: nId, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                if case .success(let files) = result {
                    // Combine changelogs from files, or just take the latest file's changelog
                    if let latestChangelog = files.files.first(where: { !($0.changelogHtml?.isEmpty ?? true) })?.changelogHtml {
                        self.nexusChangelog = LiveNexusAPIClient.parseBlocks(latestChangelog)
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }
}

struct DependencyRow: View {
    @ObservedObject var vm: StarHubTHViewModel
    let dependency: ModDependency
    
    var body: some View {
        let status = vm.resolveDependencyStatus(for: dependency.uniqueId)
        
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dependency.uniqueId.rawValue)
                    .font(.system(size: 13, weight: .bold))
                if dependency.isRequired {
                    Text(vm.L(L10n.ModDetailExtra.required))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                } else {
                    Text(vm.L(L10n.ModDetailExtra.optional))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            switch status {
            case .active:
                Label(vm.L(L10n.ModDetailExtra.installedAndEnabled), systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .medium))
            case .disabled(let mod):
                Button {
                    vm.toggleMod(mod)
                } label: {
                    Label(vm.L(L10n.ModDetailExtra.enableMod), systemImage: "power")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(6)
            case .missing:
                Button {
                    if let url = URL(string: "https://www.nexusmods.com/stardewvalley/search/?gsearch=\(dependency.uniqueId.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label(vm.L(L10n.ModDetailExtra.searchNexus), systemImage: "magnifyingglass")
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct SpoilerView: View {
    @ObservedObject var vm: StarHubTHViewModel
    let title: String
    let content: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                    let displayTitle = (title.isEmpty || title == "tag_show_spoiler") ? vm.L(L10n.Tags.spoiler) : title
                    Text(displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(isExpanded ? "Hide" : "Show")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .pointingHandCursor()
            
            if isExpanded {
                Text(.init(content))
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

struct BBCodeView: View {
    @ObservedObject var vm: StarHubTHViewModel
    let blocks: [LiveNexusAPIClient.DescriptionBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let txt):
                    Text(.init(txt))
                        .font(.body)
                        .textSelection(.enabled)
                case .image(let url):
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit().frame(maxHeight: 400).cornerRadius(8)
                        } else if phase.error != nil {
                            Text("Failed to load image").foregroundColor(.red).font(.caption)
                        } else {
                            ProgressView()
                        }
                    }
                case .spoiler(let title, let content):
                    SpoilerView(vm: vm, title: title, content: content)
                }
            }
        }
    }
}

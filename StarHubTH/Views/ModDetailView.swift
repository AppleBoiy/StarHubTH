import SwiftUI

struct ModDetailView: View {
    @ObservedObject var vm: StarHubTHViewModel
    let mod: ModItem
    
    @State private var selectedTab: Int
    @State private var coverUrl: URL? = nil
    @State private var nexusDescription: String? = nil
    @State private var nexusChangelog: String? = nil
    @State private var isLoading: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    
    init(vm: StarHubTHViewModel, mod: ModItem, initialTab: Int = 0) {
        self.vm = vm
        self.mod = mod
        self._selectedTab = State(initialValue: initialTab)
    }
    
    var localChangelog: String? {
        let basePath = (vm.gameDir as NSString).appendingPathComponent(mod.isEnabled ? "Mods" : "Mods_disabled")
        let modPath = (basePath as NSString).appendingPathComponent(mod.folderName)
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                if let coverUrl = coverUrl {
                    AsyncImage(url: coverUrl) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(width: 80, height: 80)
                             .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        ProgressView().frame(width: 80, height: 80)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mod.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("v\(mod.version) • \(mod.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        ProgressView().controlSize(.small)
                            .padding(.top, 4)
                    }
                    
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
                            .font(.system(size: 11))
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.leading, coverUrl == nil ? 0 : 8)
                
                Spacer()
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text(vm.L(L10n.Settings.nexusDescription)).tag(0)
                Text(vm.L(L10n.Settings.nexusChangelog)).tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Content
            ScrollView {
                VStack(alignment: .leading) {
                    if selectedTab == 0 {
                        Text(nexusDescription ?? mod.description)
                            .font(.body)
                            .textSelection(.enabled)
                    } else if selectedTab == 1 {
                        if let cLog = nexusChangelog {
                            Text(cLog)
                                .font(.body)
                                .textSelection(.enabled)
                        } else if let locLog = localChangelog {
                            Text(locLog)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(vm.L(L10n.Settings.nexusNoChangelog))
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .frame(width: 600, height: 500)
        .onAppear(perform: loadNexusInfo)
    }
    
    private func loadNexusInfo() {
        let apiKey = vm.nexusApiKey
        guard !apiKey.isEmpty, let nId = nexusId else { return }
        
        isLoading = true
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        NexusAPIService.shared.getModInfo(modId: nId, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                if case .success(let info) = result {
                    if let pic = info.pictureUrl {
                        self.coverUrl = URL(string: pic)
                    }
                    self.nexusDescription = NexusAPIService.stripHTML(info.description)
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.enter()
        NexusAPIService.shared.getModFiles(modId: nId, apiKey: apiKey) { result in
            DispatchQueue.main.async {
                if case .success(let files) = result {
                    // Combine changelogs from files, or just take the latest file's changelog
                    if let latestChangelog = files.files.first(where: { $0.changelogHtml != nil && !$0.changelogHtml!.isEmpty })?.changelogHtml {
                        self.nexusChangelog = NexusAPIService.stripHTML(latestChangelog)
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

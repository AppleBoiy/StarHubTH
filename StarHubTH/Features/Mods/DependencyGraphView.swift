import SwiftUI

struct DependencyGraphView: View {
    let mod: ModItem
    @ObservedObject var vm: StarHubTHViewModel
    
    // Check if there are any missing required dependencies
    var missingDeps: [ModDependency] {
        mod.dependencies.filter { dep in
            dep.isRequired && vm.resolveDependencyStatus(for: dep.uniqueId) != .active
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 0) {
                    // Parent Mod Node
                    ModNodeView(mod: mod, status: mod.isEnabled ? .active : .disabled(mod), vm: vm)
                    
                    if !mod.dependencies.isEmpty {
                        // Horizontal connector
                        Rectangle()
                            .fill(Color.primary.opacity(0.2))
                            .frame(width: 30, height: 2)
                        
                        // Vertical connector + Children
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(mod.dependencies.enumerated()), id: \.element.uniqueId) { idx, dep in
                                HStack(spacing: 0) {
                                    // Connection Path
                                    ConnectionPathView(isFirst: idx == 0, isLast: idx == mod.dependencies.count - 1, count: mod.dependencies.count)
                                        .frame(width: 30)
                                    
                                    DependencyNodeView(dep: dep, vm: vm)
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(20)
            }
            .background(Color.secondary.opacity(0.03))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            
            // Auto-Resolve Button
            if !missingDeps.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    Text(String(format: vm.L(L10n.Mods.missingDependencies), missingDeps.map { $0.uniqueId.rawValue }.joined(separator: ", ")))
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button {
                        downloadMissing()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.app.fill")
                            Text(vm.L(L10n.ModPacksExtra.downloadMissing))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .pointingHandCursor()
                }
                .padding()
                .background(Color.orange.opacity(0.05))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func downloadMissing() {
        for dep in missingDeps {
            if let url = URL(string: "https://www.nexusmods.com/stardewvalley/search/?gsearch=\(dep.uniqueId.rawValue)") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

struct ModNodeView: View {
    let mod: ModItem
    let status: DependencyStatus
    @ObservedObject var vm: StarHubTHViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mod.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(mod.author)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, y: 2)
    }
}

struct DependencyNodeView: View {
    let dep: ModDependency
    @ObservedObject var vm: StarHubTHViewModel
    
    var body: some View {
        let status = vm.resolveDependencyStatus(for: dep.uniqueId)
        let targetMod = vm.mods.first(where: { $0.uniqueId.rawValue.caseInsensitiveCompare(dep.uniqueId.rawValue) == .orderedSame })
        
        HStack(spacing: 12) {
            // Icon based on status
            ZStack {
                Circle()
                    .fill(statusColor(status).opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: statusIcon(status))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(statusColor(status))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(targetMod?.name ?? dep.uniqueId.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                if targetMod == nil {
                    Text(dep.uniqueId.rawValue)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 6) {
                    Text(dep.isRequired ? vm.L(L10n.Profiles.required) : vm.L(L10n.Profiles.optional))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(dep.isRequired ? .orange : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(dep.isRequired ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.15))
                        .cornerRadius(3)
                    
                    Text(statusText(status))
                        .font(.system(size: 9))
                        .foregroundColor(statusColor(status))
                }
            }
            
            Spacer()
            
            if status == .missing {
                Button {
                    if let url = URL(string: "https://www.nexusmods.com/stardewvalley/search/?gsearch=\(dep.uniqueId.rawValue)") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandCursor()
            } else if let targetMod = targetMod, !targetMod.nexusUrl.isEmpty {
                Button {
                    if let url = URL(string: targetMod.nexusUrl) {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
                .pointingHandCursor()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(width: 260, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(statusColor(status).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }
    
    private func statusColor(_ status: DependencyStatus) -> Color {
        switch status {
        case .active: return .green
        case .disabled: return .yellow
        case .missing: return dep.isRequired ? .red : .gray
        }
    }
    
    private func statusIcon(_ status: DependencyStatus) -> String {
        switch status {
        case .active: return "checkmark"
        case .disabled: return "pause.fill"
        case .missing: return dep.isRequired ? "xmark" : "questionmark"
        }
    }
    
    private func statusText(_ status: DependencyStatus) -> String {
        switch status {
        case .active: return vm.L(L10n.Mods.enabled)
        case .disabled: return "Installed (Disabled)"
        case .missing: return "Missing"
        }
    }
}

struct ConnectionPathView: View {
    let isFirst: Bool
    let isLast: Bool
    let count: Int
    
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                let midY = h / 2
                
                if count == 1 {
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: w, y: midY))
                } else {
                    let topY = isFirst ? midY : 0
                    let bottomY = isLast ? midY : h
                    
                    path.move(to: CGPoint(x: 0, y: topY))
                    path.addLine(to: CGPoint(x: 0, y: bottomY))
                    
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: w, y: midY))
                }
            }
            .stroke(Color.primary.opacity(0.2), lineWidth: 2)
        }
    }
}

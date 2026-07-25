import SwiftUI

struct ModSectionGroup: View {
    let title: String
    let mods: [Mod]
    @AppStorage("modListViewMode") private var viewMode: String = "list"
    @State private var expandedGroups: [Mod.FolderName: Bool] = [:]

    let columns = [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]

    var body: some View {
        StandardSection(title: title) {
            if viewMode == "grid" {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(mods, id: \.id) { mod in
                        if case .group(let children) = mod.kind {
                            ModCardView(mod: mod, isChild: false, isGroupHeader: true, isExpanded: Binding(
                                get: { expandedGroups[mod.id, default: false] },
                                set: { expandedGroups[mod.id] = $0 }
                            ))
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedGroups[mod.id, default: false].toggle()
                                }
                            }

                            if expandedGroups[mod.id] == true {
                                ForEach(children, id: \.id) { child in
                                    ModCardView(mod: child, isChild: true, isGroupHeader: false, isExpanded: .constant(false))
                                }
                            }
                        } else {
                            ModCardView(mod: mod, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(mods.enumerated()), id: \.element.id) { idx, mod in
                        if case .group(let children) = mod.kind {
                            ModGroupRow(mod: mod, children: children)
                        } else {
                            ModListRow(mod: mod, isChild: false, isGroupHeader: false, isExpanded: .constant(false))
                        }

                        if idx < mods.count - 1 {
                            Rectangle()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 1)
                                .padding(.leading, 48)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, -8)
            }
        }
    }
}

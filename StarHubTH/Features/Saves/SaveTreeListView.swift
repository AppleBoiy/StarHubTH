import SwiftUI

struct SaveTreeListView: View {
    @EnvironmentObject var savesStore: SavesStore
    let nodes: [SaveNode]
    let depth: Int
    @State private var expandedSaves: Set<String> = []

    var body: some View {
        ForEach(nodes) { node in
            let hasChildren = !node.children.isEmpty
            let isExpanded = expandedSaves.contains(node.info.folderName)

            Button(action: { savesStore.editingSave = node.info }) {
                SaveRow(
                    save: node.info,
                    depth: depth,
                    hasChildren: hasChildren,
                    isExpanded: isExpanded,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedSaves.remove(node.info.folderName)
                            } else {
                                expandedSaves.insert(node.info.folderName)
                            }
                        }
                    }
                )
            }
            .buttonStyle(.plain)

            if hasChildren && isExpanded {
                SaveTreeListView(nodes: node.children, depth: depth + 1)
            }
        }
    }
}

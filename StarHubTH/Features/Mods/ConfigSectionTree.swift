import SwiftUI

/// Renders a `[ConfigTreeNode]` level: leaves become `ConfigFieldRow`s, groups recurse into
/// a nested `ConfigSectionTree` under a bold heading. A genuine recursive `View` struct — no
/// `AnyView` type-erasure needed, since a struct can reference itself in its own `body`.
struct ConfigSectionTree: View {
    let nodes: [ConfigTreeNode]
    let onChange: (ConfigItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                if let item = node.item {
                    ConfigFieldRow(item: item, label: node.title, onChange: onChange)
                        .padding(.vertical, 4)
                    if index < nodes.count - 1 {
                        Divider()
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(node.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ConfigSectionTree(nodes: node.children, onChange: onChange)
                            .padding(.leading, 12)
                    }
                    if index < nodes.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

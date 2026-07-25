import Foundation

/// A node in the tree `ModConfigEditorView`'s visual editor builds from a flat
/// `[ConfigItem]` list — a leaf (`item` set) or a group heading (`item` nil, real children).
final class ConfigTreeNode: Identifiable {
    let id: String
    let title: String
    let item: ConfigItem?
    var children: [ConfigTreeNode]

    init(id: String, title: String, item: ConfigItem? = nil, children: [ConfigTreeNode] = []) {
        self.id = id
        self.title = title
        self.item = item
        self.children = children
    }
}

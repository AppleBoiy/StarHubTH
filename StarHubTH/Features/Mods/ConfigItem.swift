import Foundation

/// In-memory representation of one editable value inside a mod's `config.json`, used by
/// `ModConfigEditorView`'s visual editor. Not a domain model — it's transient view-editing
/// state, so it stays in `Features/Mods/` rather than `Models/`.
struct ConfigItem: Identifiable {
    let id = UUID()
    let keyPath: [String]
    var key: String { keyPath.joined(separator: " > ") }
    var boolValue: Bool = false
    var stringValue: String = ""
    var numberValue: Double = 0
    var isInt: Bool = false

    enum ItemType {
        case boolean, string, number, other
    }
    var type: ItemType
    var originalValue: Any? // Keep nested arrays/objects unmodified
}

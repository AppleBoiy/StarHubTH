import Foundation

/// I/O boundary for per-save tags/notes/icons, backed by UserDefaults. `SaveNotesStore`
/// is the `Live` implementation; a `Stub` conformance lets stores be tested in isolation.
@MainActor
protocol SaveNoteStoring {
    func note(for folderName: String) -> SaveNote
    func setNote(_ note: String, tag: String, forSave folderName: String, customIconPath: String?)
}

extension SaveNotesStore: SaveNoteStoring {}

import Foundation

/// I/O boundary for per-save tags/notes/icons, backed by UserDefaults. `SaveNotesStore`
/// is the `Live` implementation; a `Stub` conformance lets stores be tested in isolation.
protocol SaveNoteStoring {
    func note(for folderName: String) -> SaveNote
    func setNote(for folderName: String, tag: String, note: String, customIconPath: String?)
}

extension SaveNotesStore: SaveNoteStoring {}

import Foundation

final class StubSaveNoteStoring: SaveNoteStoring {
    private var notes: [String: SaveNote] = [:]

    func note(for folderName: String) -> SaveNote {
        notes[folderName] ?? SaveNote(tag: "", note: "", customIconPath: nil)
    }

    func setNote(for folderName: String, tag: String, note: String, customIconPath: String?) {
        notes[folderName] = SaveNote(tag: tag, note: note, customIconPath: customIconPath)
    }
}

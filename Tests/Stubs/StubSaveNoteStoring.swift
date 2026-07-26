import Foundation
@testable import StarHubTH

final class StubSaveNoteStoring: SaveNoteStoring {
    private var notes: [String: SaveNote] = [:]

    func note(for folderName: String) -> SaveNote {
        notes[folderName] ?? SaveNote(tag: "", note: "", customIconPath: nil)
    }

    func setNote(_ note: String, tag: String, forSave folderName: String, customIconPath: String?) {
        notes[folderName] = SaveNote(tag: tag, note: note, customIconPath: customIconPath)
    }
}

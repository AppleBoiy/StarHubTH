import Foundation

/// `cache` is genuine mutable state, so unlike this phase's other flagged singletons a
/// plain `Sendable` conformance would be dishonest — `@MainActor` is the correct fix. Now
/// safe to apply: `SavesStore` (its sole caller, via `SaveNoteStoring`) is also `@MainActor`
/// as of this same pass, so the conformance no longer crosses an isolation boundary.
@MainActor
final class SaveNotesStore {
    static let shared = SaveNotesStore()
    private let key = "SaveNotes_v2" // Upgraded version key to prevent conflicts

    private var cache: [String: SaveNote] = [:]

    init() { load() }

    func note(for folderName: String) -> SaveNote {
        cache[folderName] ?? SaveNote(tag: "", note: "", customIconPath: nil)
    }

    func setNote(_ note: String, tag: String, forSave folderName: String, customIconPath: String? = nil) {
        cache[folderName] = SaveNote(tag: tag, note: note, customIconPath: customIconPath)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: SaveNote].self, from: data)
        else { return }
        cache = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

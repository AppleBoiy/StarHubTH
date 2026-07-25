import Foundation

/// `cache` is genuine mutable state, so unlike this phase's other flagged singletons a
/// plain `Sendable` conformance would be dishonest. The correct fix is `@MainActor`, but
/// applying it here alone doesn't silence the compiler's conformance-isolation warning —
/// that only clears once `SavesStore` (its sole caller, via `SaveNoteStoring`) is also
/// `@MainActor`. Deferred to Phase 5.3's store sweep, done together.
final class SaveNotesStore {
    static let shared = SaveNotesStore()
    private let key = "SaveNotes_v2" // Upgraded version key to prevent conflicts

    private var cache: [String: SaveNote] = [:]

    init() { load() }

    func note(for folderName: String) -> SaveNote {
        cache[folderName] ?? SaveNote(tag: "", note: "", customIconPath: nil)
    }

    func setNote(for folderName: String, tag: String, note: String, customIconPath: String? = nil) {
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

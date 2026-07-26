import Foundation
import UniformTypeIdentifiers

/// I/O boundary over `NSOpenPanel`. `LiveFilePicker` is the only conformance allowed to
/// import `Cocoa` (§3.4) — everything else, including stores, goes through this protocol
/// so file-picking flows can be tested without presenting a real panel.
@MainActor
protocol FilePicking {
    /// Presents a directory picker. Returns `nil` if the user cancels. A `nil` title
    /// leaves the panel's default system title in place.
    func pickDirectory(title: String?) -> URL?

    /// Presents a file/folder picker. Returns an empty array if the user cancels. A
    /// `nil` title leaves the panel's default system title in place.
    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL]

    /// Presents a save panel pre-filled with `suggestedName`. Returns `nil` if the user
    /// cancels. A `nil` title leaves the panel's default system title in place.
    func pickSaveLocation(title: String?, suggestedName: String, allowedContentTypes: [UTType]) -> URL?

    /// Reveals a file or folder in Finder. The other AppKit-confinement half of this
    /// protocol — `NSWorkspace.shared.open` belongs here, not scattered across services/stores.
    func reveal(_ url: URL)
}

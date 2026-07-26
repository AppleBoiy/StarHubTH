import AppKit
import UniformTypeIdentifiers

/// The only non-view file allowed to import `Cocoa` for panel presentation (§3.4).
/// `@MainActor` because `NSOpenPanel`/`NSSavePanel` are themselves main-actor-isolated in
/// modern AppKit, and every caller (a store) is main-actor-isolated already.
@MainActor
struct FilePicker: FilePicking {
    func pickDirectory(title: String?) -> URL? {
        let panel = NSOpenPanel()
        if let title { panel.title = title }
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] {
        let panel = NSOpenPanel()
        if let title { panel.title = title }
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }

    func pickSaveLocation(title: String?, suggestedName: String, allowedContentTypes: [UTType]) -> URL? {
        let panel = NSSavePanel()
        if let title { panel.title = title }
        panel.nameFieldStringValue = suggestedName
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

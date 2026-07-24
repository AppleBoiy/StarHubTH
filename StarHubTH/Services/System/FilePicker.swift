import AppKit
import UniformTypeIdentifiers

/// The only non-view file allowed to import `Cocoa` for panel presentation (§3.4).
struct FilePicker: FilePicking {
    func pickDirectory(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func pickFiles(title: String, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] {
        let panel = NSOpenPanel()
        panel.title = title
        if !allowedContentTypes.isEmpty {
            panel.allowedContentTypes = allowedContentTypes
        }
        panel.allowsMultipleSelection = allowsMultipleSelection
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}

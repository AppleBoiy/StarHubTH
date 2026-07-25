import Foundation
import UniformTypeIdentifiers

final class StubFilePicking: FilePicking {
    var directoryToReturn: URL?
    var filesToReturn: [URL] = []
    private(set) var revealedURLs: [URL] = []

    func pickDirectory(title: String?) -> URL? {
        directoryToReturn
    }

    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] {
        filesToReturn
    }

    func reveal(_ url: URL) {
        revealedURLs.append(url)
    }
}

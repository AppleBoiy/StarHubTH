import Foundation
import UniformTypeIdentifiers

final class StubFilePicking: FilePicking {
    var directoryToReturn: URL?
    var filesToReturn: [URL] = []

    func pickDirectory(title: String?) -> URL? {
        directoryToReturn
    }

    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] {
        filesToReturn
    }
}

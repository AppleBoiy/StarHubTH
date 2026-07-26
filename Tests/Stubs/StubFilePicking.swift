import Foundation
import UniformTypeIdentifiers
@testable import StarHubTH

final class StubFilePicking: FilePicking {
    var directoryToReturn: URL?
    var filesToReturn: [URL] = []
    var saveLocationToReturn: URL?
    private(set) var revealedURLs: [URL] = []
    private(set) var pickedSaveLocationCalls: [(title: String?, suggestedName: String, allowedContentTypes: [UTType])] = []

    func pickDirectory(title: String?) -> URL? {
        directoryToReturn
    }

    func pickFiles(title: String?, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, canChooseDirectories: Bool) -> [URL] {
        filesToReturn
    }

    func pickSaveLocation(title: String?, suggestedName: String, allowedContentTypes: [UTType]) -> URL? {
        pickedSaveLocationCalls.append((title, suggestedName, allowedContentTypes))
        return saveLocationToReturn
    }

    func reveal(_ url: URL) {
        revealedURLs.append(url)
    }
}

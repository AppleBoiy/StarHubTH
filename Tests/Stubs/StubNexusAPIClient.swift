import Foundation

/// Test double for `NexusAPIClient`. Every method hands back a configurable canned
/// result instead of making a network call.
final class StubNexusAPIClient: NexusAPIClient {
    var modInfoResult: Result<LiveNexusAPIClient.ModInfo, Error> = .failure(StubError.unconfigured)
    var modFilesResult: Result<LiveNexusAPIClient.ModFileListResponse, Error> = .failure(StubError.unconfigured)
    var downloadLinkResult: Result<[LiveNexusAPIClient.ModDownloadLink], Error> = .failure(StubError.unconfigured)
    var endorseResult: Result<Void, Error> = .success(())
    var collectionGraphResult: Result<LiveNexusAPIClient.CollectionGraph, Error> = .failure(StubError.unconfigured)

    func getModInfo(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModInfo {
        try modInfoResult.get()
    }

    func getModFiles(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModFileListResponse {
        try modFilesResult.get()
    }

    func getDownloadLink(modId: Int, fileId: Int, key: String?, expires: String?, apiKey: String) async throws -> [LiveNexusAPIClient.ModDownloadLink] {
        try downloadLinkResult.get()
    }

    func endorseMod(modId: Int, version: String?, apiKey: String) async throws {
        try endorseResult.get()
    }

    func getCollectionGraph(slug: String, apiKey: String) async throws -> LiveNexusAPIClient.CollectionGraph {
        try collectionGraphResult.get()
    }
}

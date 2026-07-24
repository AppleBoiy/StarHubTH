import Foundation

/// Test double for `NexusAPIClient`. Every method hands back a configurable canned
/// result instead of making a network call.
final class StubNexusAPIClient: NexusAPIClient {
    var modInfoResult: Result<LiveNexusAPIClient.ModInfo, Error> = .failure(StubError.unconfigured)
    var modFilesResult: Result<LiveNexusAPIClient.ModFileListResponse, Error> = .failure(StubError.unconfigured)
    var downloadLinkResult: Result<[LiveNexusAPIClient.ModDownloadLink], Error> = .failure(StubError.unconfigured)
    var endorseResult: Result<Void, Error> = .success(())
    var collectionGraphResult: Result<LiveNexusAPIClient.CollectionGraph, Error> = .failure(StubError.unconfigured)

    func getModInfo(modId: Int, apiKey: String, completion: @escaping (Result<LiveNexusAPIClient.ModInfo, Error>) -> Void) {
        completion(modInfoResult)
    }

    func getModFiles(modId: Int, apiKey: String, completion: @escaping (Result<LiveNexusAPIClient.ModFileListResponse, Error>) -> Void) {
        completion(modFilesResult)
    }

    func getDownloadLink(modId: Int, fileId: Int, apiKey: String, completion: @escaping (Result<[LiveNexusAPIClient.ModDownloadLink], Error>) -> Void) {
        completion(downloadLinkResult)
    }

    func endorseMod(modId: Int, version: String?, apiKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(endorseResult)
    }

    func getCollectionGraph(slug: String, apiKey: String, completion: @escaping (Result<LiveNexusAPIClient.CollectionGraph, Error>) -> Void) {
        completion(collectionGraphResult)
    }
}

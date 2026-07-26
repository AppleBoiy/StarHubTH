import Foundation
@testable import StarHubTH

/// Test double for `NexusAPIClient`. Every method hands back a configurable canned
/// result instead of making a network call. `@unchecked Sendable` because it's mutated
/// only by the single test that configures it, before any concurrent use — never actually
/// shared across threads despite the `var` canned results.
final class StubNexusAPIClient: NexusAPIClient, @unchecked Sendable {
    var modInfoResult: Result<LiveNexusAPIClient.ModInfo, Error> = .failure(StubError.unconfigured)
    var modFilesResult: Result<LiveNexusAPIClient.ModFileListResponse, Error> = .failure(StubError.unconfigured)
    var downloadLinkResult: Result<[LiveNexusAPIClient.ModDownloadLink], Error> = .failure(StubError.unconfigured)
    var endorseResult: Result<Void, Error> = .success(())
    var collectionGraphResult: Result<LiveNexusAPIClient.CollectionGraph, Error> = .failure(StubError.unconfigured)

    func modInfo(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModInfo {
        try modInfoResult.get()
    }

    func modFiles(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModFileListResponse {
        try modFilesResult.get()
    }

    func downloadLink(modId: Int, fileId: Int, key: String?, expires: String?, apiKey: String) async throws -> [LiveNexusAPIClient.ModDownloadLink] {
        try downloadLinkResult.get()
    }

    func endorseMod(modId: Int, version: String?, apiKey: String) async throws {
        try endorseResult.get()
    }

    func collectionGraph(slug: String, apiKey: String) async throws -> LiveNexusAPIClient.CollectionGraph {
        try collectionGraphResult.get()
    }
}

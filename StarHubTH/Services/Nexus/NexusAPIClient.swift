import Foundation

/// I/O boundary for the Nexus Mods web API. `LiveNexusAPIClient` is the `Live` implementation;
/// a `Stub` conformance lets stores be tested without a network call.
protocol NexusAPIClient {
    func getModInfo(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModInfo
    func getModFiles(modId: Int, apiKey: String) async throws -> LiveNexusAPIClient.ModFileListResponse
    func getDownloadLink(modId: Int, fileId: Int, key: String?, expires: String?, apiKey: String) async throws -> [LiveNexusAPIClient.ModDownloadLink]
    func endorseMod(modId: Int, version: String?, apiKey: String) async throws
    func getCollectionGraph(slug: String, apiKey: String) async throws -> LiveNexusAPIClient.CollectionGraph
}

extension LiveNexusAPIClient: NexusAPIClient {}

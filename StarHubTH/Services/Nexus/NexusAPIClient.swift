import Foundation

/// I/O boundary for the Nexus Mods web API. `NexusAPIService` is the `Live` implementation;
/// a `Stub` conformance lets stores be tested without a network call.
protocol NexusAPIClient {
    func getModInfo(modId: Int, apiKey: String, completion: @escaping (Result<NexusAPIService.ModInfo, Error>) -> Void)
    func getModFiles(modId: Int, apiKey: String, completion: @escaping (Result<NexusAPIService.ModFileListResponse, Error>) -> Void)
    func getDownloadLink(modId: Int, fileId: Int, apiKey: String, completion: @escaping (Result<[NexusAPIService.ModDownloadLink], Error>) -> Void)
    func endorseMod(modId: Int, version: String?, apiKey: String, completion: @escaping (Result<Void, Error>) -> Void)
    func getCollectionGraph(slug: String, apiKey: String, completion: @escaping (Result<NexusAPIService.CollectionGraph, Error>) -> Void)
}

extension NexusAPIService: NexusAPIClient {}

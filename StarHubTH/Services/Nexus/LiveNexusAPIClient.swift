import Foundation

/// Errors surfaced by `LiveNexusAPIClient`'s HTTP/GraphQL calls, in place of a bare
/// `NSError` — callers need to tell "your API key isn't Premium" (403) and
/// "you're rate-limited" (429) apart from a generic failure to show the right message,
/// which a stringly-typed `NSError` domain/code pair doesn't make easy to check for.
enum NexusAPIError: Error, LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case noData
    case decodingFailed(String)
    case graphQLErrors(String)
    case collectionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .httpStatus(let code): return "HTTP Error: \(code)"
        case .noData: return "No data received"
        case .decodingFailed(let message): return "Failed to decode response: \(message)"
        case .graphQLErrors(let message): return "GraphQL Errors: \(message)"
        case .collectionNotFound: return "Collection not found"
        }
    }

    /// Nexus returns 403 both when no file is attached to a mod and when a non-premium
    /// API key requests a download link without the `key`/`expires` pair a manual
    /// "Download with Manager" link carries — either way, "needs a workaround, not a retry."
    var isPremiumRequired: Bool {
        if case .httpStatus(403) = self { return true }
        return false
    }

    var isRateLimited: Bool {
        if case .httpStatus(429) = self { return true }
        return false
    }
}

/// A service to interact with the Nexus Mods API (v1). `baseURL`/`gameName` are `let`
/// constants — a plain `Sendable` conformance, no actor needed (see Phase 5's Context notes).
///
/// Split across LiveNexusAPIClient.swift/LiveNexusAPIClient+Models.swift/
/// LiveNexusAPIClient+DescriptionParsing.swift (§ file-size convention) — this file owns
/// the HTTP/GraphQL core and the five endpoint methods; the Models file holds the pure
/// `Decodable` response types (no logic, so no cross-file visibility concerns); the
/// DescriptionParsing file holds `parseBlocks`/`DescriptionBlock`, a self-contained
/// BBCode/HTML-to-Markdown text utility that never touches networking state.
final class LiveNexusAPIClient: Sendable {
    static let shared = LiveNexusAPIClient()
    private let baseURL = "https://api.nexusmods.com/v1"
    private let gameName = "stardewvalley"

    private init() {}

    // MARK: - Core Fetch Method

    private func fetch<T: Decodable>(endpoint: String, apiKey: String, method: String = "GET") async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NexusAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NexusAPIError.httpStatus(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NexusAPIError.decodingFailed(error.localizedDescription)
        }
    }

    private func post(endpoint: String, apiKey: String) async throws {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NexusAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NexusAPIError.httpStatus(httpResponse.statusCode)
        }
    }

    private func postGraphQL<T: Decodable>(query: String, variables: [String: Any], apiKey: String) async throws -> T {
        let graphqlURL = "https://api.nexusmods.com/v2/graphql"
        guard let url = URL(string: graphqlURL) else {
            throw NexusAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NexusAPIError.httpStatus(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NexusAPIError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Endpoints

    func modInfo(modId: Int, apiKey: String) async throws -> ModInfo {
        let endpoint = "/games/\(gameName)/mods/\(modId).json"
        return try await fetch(endpoint: endpoint, apiKey: apiKey)
    }

    func modFiles(modId: Int, apiKey: String) async throws -> ModFileListResponse {
        let endpoint = "/games/\(gameName)/mods/\(modId)/files.json"
        return try await fetch(endpoint: endpoint, apiKey: apiKey)
    }

    /// `key`/`expires` are the one-time authorization pair from a manual "Download with
    /// Manager" `nxm://` link (see `NXMParser`). Nexus's API requires them for a
    /// non-premium API key to obtain a download link at all; a premium key ignores them.
    /// Pass `nil` for both when the caller has no `nxm://` link to source them from —
    /// the request will then only succeed for a premium API key.
    func downloadLink(modId: Int, fileId: Int, key: String?, expires: String?, apiKey: String) async throws -> [ModDownloadLink] {
        var endpoint = "/games/\(gameName)/mods/\(modId)/files/\(fileId)/download_link.json"

        if let key, let expires, !key.isEmpty, !expires.isEmpty {
            var queryItems: [String] = []
            if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryItems.append("key=\(encodedKey)")
            }
            if let encodedExpires = expires.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                queryItems.append("expires=\(encodedExpires)")
            }
            if !queryItems.isEmpty {
                endpoint += "?" + queryItems.joined(separator: "&")
            }
        }

        return try await fetch(endpoint: endpoint, apiKey: apiKey)
    }

    func endorseMod(modId: Int, version: String?, apiKey: String) async throws {
        // Technically nexus requires version but it's optional in their query params sometimes, or we can just send the one we know.
        var endpoint = "/games/\(gameName)/mods/\(modId)/endorse.json"
        if let v = version, !v.isEmpty {
            if let encoded = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                endpoint += "?version=\(encoded)"
            }
        }
        try await post(endpoint: endpoint, apiKey: apiKey)
    }

    func collectionGraph(slug: String, apiKey: String) async throws -> CollectionGraph {
        let query = """
        query GetCollection($slug: String!) {
            collection(slug: $slug) {
                id
                slug
                name
                summary
                endorsements
                totalDownloads
                updatedAt
                tileImage {
                    url
                }
                user {
                    name
                }
                latestPublishedRevision {
                    revisionNumber
                    downloadLink
                    gameVersions {
                        reference
                    }
                    modFiles {
                        fileId
                        optional
                        file {
                            fileId
                            name
                            version
                            sizeInBytes
                            mod {
                                modId
                                name
                                author
                                downloads
                                updatedAt
                                thumbnailUrl
                            }
                        }
                    }
                }
                game {
                    domainName
                }
            }
        }
        """
        let response: GraphQLResponse<CollectionData> = try await postGraphQL(query: query, variables: ["slug": slug], apiKey: apiKey)

        if let errors = response.errors, !errors.isEmpty {
            let errStr = errors.map { $0.message }.joined(separator: ", ")
            throw NexusAPIError.graphQLErrors(errStr)
        }
        guard let collection = response.data?.collection else {
            throw NexusAPIError.collectionNotFound
        }
        return collection
    }
}

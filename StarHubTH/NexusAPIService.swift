import Foundation

/// A service to interact with the Nexus Mods API (v1).
class NexusAPIService {
    static let shared = NexusAPIService()
    private let baseURL = "https://api.nexusmods.com/v1"
    private let gameName = "stardewvalley"
    
    // MARK: - API Models
    
    struct ModInfo: Decodable {
        let name: String
        let summary: String
        let description: String
        let pictureUrl: String?
        let version: String?
        let author: String?
        let categoryId: Int?
        
        enum CodingKeys: String, CodingKey {
            case name
            case summary
            case description
            case pictureUrl = "picture_url"
            case version
            case author
            case categoryId = "category_id"
        }
    }
    
    /// Map Nexus Mods category ID for Stardew Valley to our internal Tag strings
    static func categoryTag(from categoryId: Int) -> String {
        switch categoryId {
        case 2: return "tag_nexus_2"
        case 3: return "tag_nexus_3"
        case 4: return "tag_nexus_4"
        case 5: return "tag_nexus_5"
        case 6: return "tag_nexus_6"
        case 7: return "tag_nexus_7"
        case 8: return "tag_nexus_8"
        case 9: return "tag_nexus_9"
        case 10: return "tag_nexus_10"
        case 11: return "tag_nexus_11"
        case 12: return "tag_nexus_12"
        case 13: return "tag_nexus_13"
        case 14: return "tag_nexus_14"
        case 15: return "tag_nexus_15"
        case 16: return "tag_nexus_16"
        case 17: return "tag_nexus_17"
        case 18: return "tag_nexus_18"
        case 19: return "tag_nexus_19"
        case 20: return "tag_nexus_20"
        case 21: return "tag_nexus_21"
        case 22: return "tag_nexus_22"
        case 23: return "tag_nexus_23"
        case 24: return "tag_nexus_24"
        case 25: return "tag_nexus_25"
        case 26: return "tag_nexus_26"
        case 27: return "tag_nexus_27"
        default: return "Other"
        }
    }
    
    struct ModFile: Decodable {
        let fileId: Int
        let name: String
        let version: String
        let categoryId: Int
        let changelogHtml: String?
        
        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case name
            case version
            case categoryId = "category_id"
            case changelogHtml = "changelog_html"
        }
    }
    
    struct ModFileListResponse: Decodable {
        let files: [ModFile]
    }
    
    struct ModDownloadLink: Decodable {
        let name: String
        let shortName: String
        let URI: String
        
        enum CodingKeys: String, CodingKey {
            case name
            case shortName = "short_name"
            case URI
        }
    }
    
    // MARK: - GraphQL Models
    
    struct GraphQLResponse<T: Decodable>: Decodable {
        let data: T?
        let errors: [GraphQLError]?
    }
    
    struct GraphQLError: Decodable {
        let message: String
    }
    
    struct CollectionData: Decodable {
        let collection: CollectionGraph?
    }
    
    struct CollectionGraph: Decodable {
        let id: Int
        let slug: String
        let name: String
        let summary: String?
        let latestPublishedRevision: CollectionRevision?
        let game: CollectionGame?
    }
    
    struct CollectionRevision: Decodable {
        let revisionNumber: Int
        let downloadLink: String?
        let modFiles: [CollectionModFile]?
    }
    
    struct CollectionModFile: Decodable {
        let fileId: Int?
        let optional: Bool?
        let file: CollectionFileDetail?
    }
    
    struct CollectionFileDetail: Decodable {
        let fileId: Int
        let name: String
        let version: String?
        let sizeInBytes: String?
        let mod: CollectionModDetail?
    }
    
    struct CollectionModDetail: Decodable {
        let modId: Int
        let name: String
        let pictureUrl: String?
    }
    
    struct CollectionGame: Decodable {
        let domainName: String
    }
    
    private init() {}
    
    // MARK: - Core Fetch Method
    
    private func fetch<T: Decodable>(endpoint: String, apiKey: String, method: String = "GET", completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(NSError(domain: "NexusAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let statusError = NSError(domain: "NexusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
                completion(.failure(statusError))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NexusAPI", code: 204, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    private func post(endpoint: String, apiKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(NSError(domain: "NexusAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let statusError = NSError(domain: "NexusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
                completion(.failure(statusError))
                return
            }
            
            completion(.success(()))
        }
        task.resume()
    }
    
    private func postGraphQL<T: Decodable>(query: String, variables: [String: Any], apiKey: String, completion: @escaping (Result<T, Error>) -> Void) {
        let graphqlURL = "https://api.nexusmods.com/v2/graphql"
        guard let url = URL(string: graphqlURL) else {
            completion(.failure(NSError(domain: "NexusAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
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
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let statusError = NSError(domain: "NexusAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"])
                completion(.failure(statusError))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "NexusAPI", code: 204, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("GraphQL Data: \(jsonString)")
                }
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Endpoints
    
    func getModInfo(modId: Int, apiKey: String, completion: @escaping (Result<ModInfo, Error>) -> Void) {
        let endpoint = "/games/\(gameName)/mods/\(modId).json"
        fetch(endpoint: endpoint, apiKey: apiKey, completion: completion)
    }
    
    func getModFiles(modId: Int, apiKey: String, completion: @escaping (Result<ModFileListResponse, Error>) -> Void) {
        let endpoint = "/games/\(gameName)/mods/\(modId)/files.json"
        fetch(endpoint: endpoint, apiKey: apiKey, completion: completion)
    }
    
    func getDownloadLink(modId: Int, fileId: Int, apiKey: String, completion: @escaping (Result<[ModDownloadLink], Error>) -> Void) {
        let endpoint = "/games/\(gameName)/mods/\(modId)/files/\(fileId)/download_link.json"
        fetch(endpoint: endpoint, apiKey: apiKey, completion: completion)
    }
    
    func endorseMod(modId: Int, version: String?, apiKey: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Technically nexus requires version but it's optional in their query params sometimes, or we can just send the one we know.
        var endpoint = "/games/\(gameName)/mods/\(modId)/endorse.json"
        if let v = version, !v.isEmpty {
            if let encoded = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                endpoint += "?version=\(encoded)"
            }
        }
        post(endpoint: endpoint, apiKey: apiKey, completion: completion)
    }
    
    func getCollectionGraph(slug: String, apiKey: String, completion: @escaping (Result<CollectionGraph, Error>) -> Void) {
        let query = """
        query GetCollection($slug: String!) {
            collection(slug: $slug) {
                id
                slug
                name
                summary
                latestPublishedRevision {
                    revisionNumber
                    downloadLink
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
                                pictureUrl
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
        postGraphQL(query: query, variables: ["slug": slug], apiKey: apiKey) { (result: Result<GraphQLResponse<CollectionData>, Error>) in
            switch result {
            case .success(let response):
                if let errors = response.errors, !errors.isEmpty {
                    let errStr = errors.map { $0.message }.joined(separator: ", ")
                    completion(.failure(NSError(domain: "NexusAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "GraphQL Errors: \(errStr)"])))
                    return
                }
                guard let collection = response.data?.collection else {
                    completion(.failure(NSError(domain: "NexusAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "Collection not found"])))
                    return
                }
                completion(.success(collection))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    enum DescriptionBlock: Hashable {
        case text(String)
        case image(URL)
        case spoiler(title: String, content: String)
    }
    
    // Helper: format HTML and BBCode into basic Markdown and extract images & spoilers
    static func parseBlocks(_ str: String) -> [DescriptionBlock] {
        var formatted = str
        
        // 1. Basic HTML Entities
        formatted = formatted.replacingOccurrences(of: "&nbsp;", with: " ")
                             .replacingOccurrences(of: "&amp;", with: "&")
                             .replacingOccurrences(of: "&lt;", with: "<")
                             .replacingOccurrences(of: "&gt;", with: ">")
                             .replacingOccurrences(of: "&quot;", with: "\"")
        
        // 2. Convert <br> and HTML block tags to newlines so text doesn't run together
        formatted = formatted.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)</?(?:p|div|h[1-6]|li|tr|blockquote)\\b[^>]*>", with: "\n", options: .regularExpression)
        
        // 3. Strip all other HTML tags
        formatted = formatted.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 4. Convert BBCode to Markdown using (?s) to match across newlines
        // Note: We use \s* inside the capture groups so that leading/trailing newlines don't break Markdown rendering (e.g. ** text ** is invalid Markdown)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[b\\]\\s*(.*?)\\s*\\[/b\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[i\\]\\s*(.*?)\\s*\\[/i\\]", with: "*$1*", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[s\\]\\s*(.*?)\\s*\\[/s\\]", with: "~~$1~~", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[u\\]\\s*(.*?)\\s*\\[/u\\]", with: "*$1*", options: [.regularExpression, .caseInsensitive])
        
        // Headers (Size tags and heading tags)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[size=[^\\]]+\\]\\s*(.*?)\\s*\\[/size\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[heading[=\\d]*\\]\\s*(.*?)\\s*\\[/heading\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])
        
        // Lists
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/?list(?:=[^\\]]+)?\\]", with: "\n", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[\\*\\]", with: "\n- ", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[li\\]", with: "\n- ", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/li\\]", with: "", options: .regularExpression)
        
        // Links
        formatted = formatted.replacingOccurrences(of: "(?s)\\[url=(.*?)\\]\\s*(.*?)\\s*\\[/url\\]", with: "[$2]($1)", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[url\\]\\s*(.*?)\\s*\\[/url\\]", with: "[$1]($1)", options: [.regularExpression, .caseInsensitive])
        
        // Horizontal Rules
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/?(?:line|hr)\\]", with: "\n---\n", options: .regularExpression)
        
        // 5. Strip remaining formatting BBCode tags (keeping their inner content)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[/?(?:color|center|left|right|font|align|quote|sub|sup|code)(?:=[^\\]]+)?\\]", with: "", options: [.regularExpression, .caseInsensitive])
        
        // 6. Tokenize by [img] and [spoiler] tags
        var blocks: [DescriptionBlock] = []
        let combinedPattern = "(?s)(\\[img\\](.*?)\\[/img\\]|\\[spoiler(?:=(.*?))?\\](.*?)\\[/spoiler\\])"
        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive) else {
            return [.text(formatted.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        
        let nsString = formatted as NSString
        let matches = regex.matches(in: formatted, range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        for match in matches {
            let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let textStr = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !textStr.isEmpty {
                blocks.append(.text(textStr))
            }
            
            let fullMatch = nsString.substring(with: match.range)
            if fullMatch.lowercased().hasPrefix("[img]") {
                let imgUrlRange = match.range(at: 2)
                if imgUrlRange.location != NSNotFound {
                    let imgUrlStr = nsString.substring(with: imgUrlRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: imgUrlStr) {
                        blocks.append(.image(url))
                    }
                }
            } else if fullMatch.lowercased().hasPrefix("[spoiler") {
                let titleRange = match.range(at: 3)
                let contentRange = match.range(at: 4)
                
                var titleStr = "Spoiler"
                if titleRange.location != NSNotFound {
                    let extracted = nsString.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty {
                        titleStr = extracted
                    }
                }
                
                var contentStr = ""
                if contentRange.location != NSNotFound {
                    contentStr = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                blocks.append(.spoiler(title: titleStr, content: contentStr))
            }
            
            lastEnd = match.range.location + match.range.length
        }
        
        let finalText = nsString.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            blocks.append(.text(finalText))
        }
        
        return blocks
    }
}

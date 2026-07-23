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
    
    // Helper: strip HTML tags
    static func stripHTML(_ str: String) -> String {
        return str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                  .replacingOccurrences(of: "&nbsp;", with: " ")
                  .replacingOccurrences(of: "&amp;", with: "&")
                  .replacingOccurrences(of: "&lt;", with: "<")
                  .replacingOccurrences(of: "&gt;", with: ">")
                  .replacingOccurrences(of: "&quot;", with: "\"")
    }
}

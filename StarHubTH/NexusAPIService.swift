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
    
    enum DescriptionBlock: Hashable {
        case text(String)
        case image(URL)
    }
    
    // Helper: format HTML and BBCode into basic Markdown and extract images
    static func parseBlocks(_ str: String) -> [DescriptionBlock] {
        var formatted = str
        
        // 1. Basic HTML Entities
        formatted = formatted.replacingOccurrences(of: "&nbsp;", with: " ")
                             .replacingOccurrences(of: "&amp;", with: "&")
                             .replacingOccurrences(of: "&lt;", with: "<")
                             .replacingOccurrences(of: "&gt;", with: ">")
                             .replacingOccurrences(of: "&quot;", with: "\"")
        
        // 2. Convert <br> and <br/> to newlines
        formatted = formatted.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        
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
        
        // Spoilers
        formatted = formatted.replacingOccurrences(of: "(?s)\\[spoiler\\]\\s*(.*?)\\s*\\[/spoiler\\]", with: "\n*--- Spoiler ---*\n$1\n*--- End Spoiler ---*\n", options: [.regularExpression, .caseInsensitive])
        
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
        
        // 6. Split by [img] tags
        var blocks: [DescriptionBlock] = []
        let pattern = "(?s)\\[img\\](.*?)\\[/img\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [.text(formatted.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        
        let nsString = formatted as NSString
        let results = regex.matches(in: formatted, range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        for match in results {
            let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let textStr = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !textStr.isEmpty {
                blocks.append(.text(textStr))
            }
            
            let imgUrlRange = match.range(at: 1)
            let imgUrlStr = nsString.substring(with: imgUrlRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: imgUrlStr) {
                blocks.append(.image(url))
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

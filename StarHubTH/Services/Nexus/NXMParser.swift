import Foundation

enum NXMParsedResult {
    case mod(modId: Int, fileId: Int)
    case collection(slug: String)
}

struct NXMParser {
    static func parse(url: URL) -> NXMParsedResult? {
        guard url.scheme?.lowercased() == "nxm" else { return nil }
        
        let path = url.path
        let host = url.host?.lowercased() ?? ""
        
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        if host == "stardewvalley" {
            if components.count >= 4 && components[0].lowercased() == "mods" && components[2].lowercased() == "files" {
                if let modId = Int(components[1]), let fileId = Int(components[3]) {
                    return .mod(modId: modId, fileId: fileId)
                }
            } else if components.count >= 2 && components[0].lowercased() == "collections" {
                return .collection(slug: components[1])
            }
        }
        
        return nil
    }
}

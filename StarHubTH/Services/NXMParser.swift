import Foundation

struct NXMParser {
    static func parse(url: URL) -> (modId: Int, fileId: Int)? {
        guard url.scheme?.lowercased() == "nxm" else { return nil }
        
        let path = url.path
        let host = url.host ?? ""
        
        let components = path.components(separatedBy: "/")
        if host.lowercased() == "stardewvalley" && components.count >= 5 && components[1].lowercased() == "mods" && components[3].lowercased() == "files" {
            if let modId = Int(components[2]), let fileId = Int(components[4]) {
                return (modId, fileId)
            }
        }
        
        return nil
    }
}

import Foundation

enum NXMParsedResult {
    /// `key`/`expires` are the one-time authorization pair Nexus attaches to a manual
    /// "Download with Manager" link. A non-premium API key can only fetch a download
    /// link through the API when these are forwarded alongside it — without them, Nexus
    /// rejects the request outright for non-premium accounts.
    case mod(modId: Int, fileId: Int, key: String?, expires: String?)
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
                    let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                    let key = queryItems.first(where: { $0.name == "key" })?.value
                    let expires = queryItems.first(where: { $0.name == "expires" })?.value
                    return .mod(modId: modId, fileId: fileId, key: key, expires: expires)
                }
            } else if components.count >= 2 && components[0].lowercased() == "collections" {
                return .collection(slug: components[1])
            }
        }

        return nil
    }
}

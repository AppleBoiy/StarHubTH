import Foundation

struct SaveFileParser {
    static func parse(url: URL, folderName: String) -> SaveGameInfo? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        
        let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
        let lastModified = attr?[.modificationDate] as? Date ?? Date()
        
        return parse(xml: content, url: url, folderName: folderName, lastModified: lastModified)
    }
    
    static func parse(xml content: String, url: URL, folderName: String, lastModified: Date) -> SaveGameInfo? {
        let playerName = extractTag(tag: "name", from: content) ?? "Unknown"
        let farmName = extractTag(tag: "farmName", from: content) ?? "Unknown"
        let favoriteThing = extractTag(tag: "favoriteThing", from: content) ?? "Unknown"
        let money = Int(extractTag(tag: "money", from: content) ?? "0") ?? 0
        let spouse = extractSpouseFromPlayer(from: content) ?? ""
        
        let year = Int(extractTag(tag: "yearForSaveGame", from: content) ?? "1") ?? 1
        let season = Int(extractTag(tag: "seasonForSaveGame", from: content) ?? "0") ?? 0
        let day = Int(extractTag(tag: "dayOfMonthForSaveGame", from: content) ?? "1") ?? 1
        let whichFarm = Int(extractTag(tag: "whichFarm", from: content) ?? "0") ?? 0
        
        // Advanced
        let maxHealth = Int(extractTag(tag: "maxHealth", from: content) ?? "100") ?? 100
        let maxStamina = Int(extractTag(tag: "maxStamina", from: content) ?? "270") ?? 270
        let goldenWalnuts = Int(extractTag(tag: "goldenWalnuts", from: content) ?? "0") ?? 0
        let qiGems = Int(extractTag(tag: "qiGems", from: content) ?? "0") ?? 0
        let clubCoins = Int(extractTag(tag: "clubCoins", from: content) ?? "0") ?? 0
        let totalMoneyEarned = Int(extractTag(tag: "totalMoneyEarned", from: content) ?? "0") ?? 0
        
        return SaveGameInfo(
            folderName: folderName,
            fileURL: url,
            lastModified: lastModified,
            playerName: playerName,
            farmName: farmName,
            favoriteThing: favoriteThing,
            money: money,
            spouse: spouse,
            maxHealth: maxHealth,
            maxStamina: maxStamina,
            goldenWalnuts: goldenWalnuts,
            qiGems: qiGems,
            clubCoins: clubCoins,
            totalMoneyEarned: totalMoneyEarned,
            year: year,
            season: season,
            day: day,
            whichFarm: whichFarm
        )
    }
    
    static func extractTag(tag: String, from xml: String) -> String? {
        let pattern = "<\(tag)>([^<]+)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        if let match = regex.firstMatch(in: xml, options: [], range: range) {
            if let swiftRange = Range(match.range(at: 1), in: xml) {
                return String(xml[swiftRange])
            }
        }
        return nil
    }
    
    static func extractSpouseFromPlayer(from xml: String) -> String? {
        guard let playerStart = xml.range(of: "<player>"),
              let playerEnd = xml.range(of: "</player>", range: playerStart.upperBound..<xml.endIndex) else {
            return extractTag(tag: "spouse", from: xml)
        }
        let playerBlock = String(xml[playerStart.lowerBound..<playerEnd.upperBound])
        return extractTag(tag: "spouse", from: playerBlock)
    }
}

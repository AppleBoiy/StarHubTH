import Foundation

final class StubModScanning: ModScanning {
    var mods: [ModItem] = []
    private(set) var lastGameDir: String?
    private(set) var lastCustomModTags: [String: String]?

    func scan(gameDir: String, customModTags: [String: String]) -> [ModItem] {
        lastGameDir = gameDir
        lastCustomModTags = customModTags
        return mods
    }
}

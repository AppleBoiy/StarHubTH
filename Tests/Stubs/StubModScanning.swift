import Foundation
@testable import StarHubTH

final class StubModScanning: ModScanning {
    var mods: [Mod] = []
    private(set) var lastGameDir: String?
    private(set) var lastCustomModTags: [String: String]?

    func scan(gameDir: String, customModTags: [String: String]) -> [Mod] {
        lastGameDir = gameDir
        lastCustomModTags = customModTags
        return mods
    }
}

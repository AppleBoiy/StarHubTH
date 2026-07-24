import Foundation

struct SaveGameInfo: Identifiable, Equatable, Hashable {
    var id: String { folderName }
    let folderName: String
    let fileURL: URL
    let lastModified: Date

    var playerName: String
    var farmName: String
    var favoriteThing: String
    var money: Int
    var spouse: String   // empty string = single (no <spouse> tag)

    // Advanced Stats
    var maxHealth: Int
    var maxStamina: Int
    var goldenWalnuts: Int
    var qiGems: Int
    var clubCoins: Int
    var totalMoneyEarned: Int

    var year: Int
    var season: Int
    var day: Int
    var whichFarm: Int

    var farmTypeName: String {
        switch whichFarm {
        case 0: return "Standard Farm"
        case 1: return "Riverland Farm"
        case 2: return "Forest Farm"
        case 3: return "Hill-top Farm"
        case 4: return "Wilderness Farm"
        case 5: return "Four Corners Farm"
        case 6: return "Beach Farm"
        case 7: return "Meadowlands Farm"
        default: return "Custom Farm"
        }
    }

    var farmIcon: String {
        switch whichFarm {
        case 0: return "leaf.fill"
        case 1: return "water.waves"
        case 2: return "tree.fill"
        case 3: return "mountain.2.fill"
        case 4: return "moon.stars.fill"
        case 5: return "square.grid.2x2.fill"
        case 6: return "sun.max.fill"
        case 7: return "pawprint.fill"
        default: return "questionmark.square.fill"
        }
    }

    var seasonName: String {
        switch season {
        case 0: return L10n.Saves.spring
        case 1: return L10n.Saves.summer
        case 2: return L10n.Saves.fall
        case 3: return L10n.Saves.winter
        default: return L10n.Saves.spring
        }
    }
}

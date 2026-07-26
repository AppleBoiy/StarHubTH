import Foundation

/// Phase 4.1. Nearly every view touches this, which is why it's the first store
/// extracted from `StarHubTHViewModel` — see docs/REFACTOR_PLAN.md Phase 4.
@MainActor
final class LocalizationStore: ObservableObject {
    private static let supportedLanguages = Set(["en", "th"])

    private static func normalizedLanguage(_ language: String?) -> String {
        guard let language, supportedLanguages.contains(language) else { return defaultLanguage }
        return language
    }

    private static var defaultLanguage: String {
        Locale.preferredLanguages.contains { $0.lowercased().hasPrefix("th") } ? "th" : "en"
    }

    private let preferenceStoring: PreferenceStoring

    @Published var currentLanguage: String { // STANDARDS-EXCEPTION: §8 — SettingsView's language Picker needs a two-way Binding
        didSet {
            if !Self.supportedLanguages.contains(currentLanguage) {
                currentLanguage = "en"
                return
            }
            preferenceStoring.set(currentLanguage, forKey: "currentLanguage")
            preferenceStoring.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    init(preferenceStoring: PreferenceStoring = PreferenceStore()) {
        self.preferenceStoring = preferenceStoring
        let savedLang = Self.normalizedLanguage(preferenceStoring.string(forKey: "currentLanguage"))
        self.currentLanguage = savedLang
        // Force sync AppleLanguages with currentLanguage at startup
        preferenceStoring.set([savedLang], forKey: "AppleLanguages")
    }

    /// Returns a locale- and calendar-aware DateFormatter for short dates.
    /// - English → en_US + Gregorian → M/d/yyyy  (USA format, e.g. 3/25/2024)
    /// - Thai    → th_TH + Buddhist  → d/M/yyyy  (Thai BE, e.g. 25/3/2569)
    func makeDateFormatter(dateStyle: DateFormatter.Style = .short) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        if currentLanguage == "th" {
            formatter.locale = Locale(identifier: "th_TH")
            formatter.calendar = Calendar(identifier: .buddhist)
            // Explicit format: day/month/year in Buddhist Era
            if dateStyle == .medium {
                formatter.dateFormat = "d MMM yyyy"
            } else {
                formatter.dateFormat = "d/M/yyyy"
            }
        } else {
            formatter.locale = Locale(identifier: "en_US")
            formatter.calendar = Calendar(identifier: .gregorian)
            // USA format: month/day/year
            if dateStyle == .medium {
                formatter.dateFormat = "MMM d, yyyy"
            } else {
                formatter.dateFormat = "M/d/yyyy"
            }
        }
        return formatter
    }

    // Helper to force localization using the currently selected language bundle
    func localizedString(for key: String) -> String {
        // Build the lproj URL directly from resourceURL (more reliable for swiftc-built apps)
        if let resourceURL = Bundle.main.resourceURL {
            let lprojURL = resourceURL.appendingPathComponent("\(currentLanguage).lproj")
            if let bundle = Bundle(url: lprojURL) {
                // Must call localizedString directly on the bundle object
                let result = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
                if result != "__MISSING__" { return result }
            }
        }
        // Last resort: return key so missing translations are visible
        return key
    }

    /// Typed-key shorthand. Prefer this over localizedString(for:) with raw strings.
    /// Example: localization.L(L10n.Mods.enabled)
    func L(_ key: String) -> String {
        return localizedString(for: key)
    }

    func localizedTag(_ tag: String) -> String {
        let rawTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if rawTag.isEmpty { return rawTag }

        switch rawTag {
        case "Content Patcher": return L(L10n.Tags.contentPatcher)
        case "Framework": return L(L10n.Tags.framework)
        case "Cosmetic": return L(L10n.Tags.cosmetic)
        case "NPC": return L(L10n.Tags.npc)
        case "UI": return L(L10n.Tags.ui)
        case "Audio": return L(L10n.Tags.audio)
        case "Map": return L(L10n.Tags.map)
        case "Gameplay": return L(L10n.Tags.gameplay)
        case "Translation": return L(L10n.Tags.translation)
        case "Other": return L(L10n.Tags.other)
        case "tag_nexus_2": return L(L10n.Tags.nexus2)
        case "tag_nexus_3": return L(L10n.Tags.nexus3)
        case "tag_nexus_4": return L(L10n.Tags.nexus4)
        case "tag_nexus_5": return L(L10n.Tags.nexus5)
        case "tag_nexus_6": return L(L10n.Tags.nexus6)
        case "tag_nexus_7": return L(L10n.Tags.nexus7)
        case "tag_nexus_8": return L(L10n.Tags.nexus8)
        case "tag_nexus_9": return L(L10n.Tags.nexus9)
        case "tag_nexus_10": return L(L10n.Tags.nexus10)
        case "tag_nexus_11": return L(L10n.Tags.nexus11)
        case "tag_nexus_12": return L(L10n.Tags.nexus12)
        case "tag_nexus_13": return L(L10n.Tags.nexus13)
        case "tag_nexus_14": return L(L10n.Tags.nexus14)
        case "tag_nexus_15": return L(L10n.Tags.nexus15)
        case "tag_nexus_16": return L(L10n.Tags.nexus16)
        case "tag_nexus_17": return L(L10n.Tags.nexus17)
        case "tag_nexus_18": return L(L10n.Tags.nexus18)
        case "tag_nexus_19": return L(L10n.Tags.nexus19)
        case "tag_nexus_20": return L(L10n.Tags.nexus20)
        case "tag_nexus_21": return L(L10n.Tags.nexus21)
        case "tag_nexus_22": return L(L10n.Tags.nexus22)
        case "tag_nexus_23": return L(L10n.Tags.nexus23)
        case "tag_nexus_24": return L(L10n.Tags.nexus24)
        case "tag_nexus_25": return L(L10n.Tags.nexus25)
        case "tag_nexus_26": return L(L10n.Tags.nexus26)
        case "tag_nexus_27": return L(L10n.Tags.nexus27)
        default: return tag
        }
    }
}

import Foundation

extension ModItem {
    /// Infer a display type tag from manifest metadata.
    static func inferTag(name: String, uniqueId: String, description: String) -> String {
        let haystack = "\(name) \(uniqueId) \(description)".lowercased()

        // Helper to match exact whole words using regex, preventing false positives like "fruit" -> "ui"
        let matchWord = { (word: String) -> Bool in
            return haystack.range(of: "\\b\(word)\\b", options: .regularExpression) != nil
        }

        // Translation
        if matchWord("translation") || matchWord("language") || matchWord("locale") || matchWord("thai") || matchWord("i18n") || matchWord("spanish") || matchWord("chinese") || matchWord("korean") || matchWord("french") || matchWord("russian") || matchWord("german") {
            return "Translation"
        }

        // Framework / API
        if matchWord("framework") || matchWord("api") || matchWord("library") || matchWord("core") || matchWord("toolkit") || matchWord("util") || matchWord("utility") || haystack.contains("smapi") || (haystack.contains("spacechase") && haystack.contains("core")) {
            return "Framework"
        }

        // Content Patcher
        if haystack.contains("content patcher") || uniqueId.lowercased().hasPrefix("pathoschild.contentpatcher") || matchWord("cp") {
            return "Content Patcher"
        }

        // UI / HUD
        if matchWord("ui") || matchWord("interface") || matchWord("hud") || matchWord("menu") || matchWord("inventory") || matchWord("tooltip") || matchWord("display") || matchWord("cursor") || matchWord("minimap") {
            return "UI"
        }

        // Cosmetic / Visuals
        if matchWord("cosmetic") || matchWord("portrait") || matchWord("portraits") || matchWord("sprite") || matchWord("sprites") || matchWord("retexture") || matchWord("skin") || matchWord("hair") || matchWord("fashion") || matchWord("visual") || matchWord("texture") || matchWord("textures") || matchWord("recolor") || matchWord("appearance") || matchWord("clothes") || matchWord("shirt") || matchWord("hat") || matchWord("furniture") || matchWord("building") || matchWord("buildings") || matchWord("aesthetic") {
            return "Cosmetic"
        }

        // NPC / Dialogues
        if matchWord("npc") || matchWord("npcs") || matchWord("marriage") || matchWord("bachelor") || matchWord("bachelorette") || matchWord("villager") || matchWord("dialogue") || matchWord("dialogues") || matchWord("event") || matchWord("events") || matchWord("character") || matchWord("schedule") || matchWord("heart") {
            return "NPC"
        }

        // Audio / Music
        if matchWord("music") || matchWord("audio") || matchWord("sound") || matchWord("sounds") || matchWord("ambient") || matchWord("bgm") || matchWord("voice") || matchWord("sfx") {
            return "Audio"
        }

        // Map / Locations
        if matchWord("map") || matchWord("maps") || matchWord("location") || matchWord("locations") || matchWord("world") || matchWord("tile") || matchWord("tiles") || matchWord("expansion") || matchWord("dungeon") || matchWord("greenhouse") || matchWord("cave") || matchWord("caves") || matchWord("town") {
            return "Map"
        }

        // Gameplay / Mechanics
        if matchWord("cheat") || matchWord("time") || matchWord("speed") || matchWord("gameplay") || matchWord("harvest") || matchWord("farm") || matchWord("crop") || matchWord("crops") || matchWord("fishing") || matchWord("balance") || matchWord("combat") || matchWord("mining") || matchWord("foraging") || matchWord("animal") || matchWord("animals") || matchWord("pet") || matchWord("pets") || matchWord("economy") || matchWord("item") || matchWord("items") || matchWord("recipe") || matchWord("recipes") || matchWord("machine") || matchWord("machines") || matchWord("artisan") || matchWord("tool") || matchWord("tools") || matchWord("weapon") || matchWord("weapons") || matchWord("skill") || matchWord("skills") || matchWord("automate") || matchWord("automation") {
            return "Gameplay"
        }

        return "Other" // Catch-all for uncategorized mods
    }
}

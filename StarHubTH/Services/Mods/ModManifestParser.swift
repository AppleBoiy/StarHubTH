import Foundation

struct ModManifestParser {
    static func parse(at path: String, relativePath: String, isEnabled: Bool, customTags: [String: String]) -> ModItem? {
        let manifestPath = (path as NSString).appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestPath) else { return nil }
        
        guard let rawData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let rawString = String(data: rawData, encoding: .utf8) else { return nil }
              
        return parse(rawString: rawString, path: path, relativePath: relativePath, isEnabled: isEnabled, customTags: customTags)
    }
    
    static func parse(rawString: String, path: String, relativePath: String, isEnabled: Bool, customTags: [String: String]) -> ModItem? {
        var name = (path as NSString).lastPathComponent
        var uniqueId = ""
        var version = "Unknown"
        var author = "Unknown"
        var description = ""
        var nexusUrl = ""
        var dependencies: [ModDependency] = []
        
        // Strip block comments (/* ... */) often added by ModManifestBuilder
        let cleanString = rawString.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
        let options: JSONSerialization.ReadingOptions = [.json5Allowed]
        
        if let data = cleanString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: options) as? [String: Any] {
            
            if let mName = json.caseInsensitiveValue(forKey: "Name") as? String { name = mName }
            if let mUniqueId = json.caseInsensitiveValue(forKey: "UniqueID") as? String { uniqueId = mUniqueId }
            
            let mVer = json.caseInsensitiveValue(forKey: "Version")
            if let vStr = mVer as? String { 
                version = vStr 
            } else if let vDict = mVer as? [String: Any] {
                let major = vDict.caseInsensitiveValue(forKey: "MajorVersion") as? Int ?? 1
                let minor = vDict.caseInsensitiveValue(forKey: "MinorVersion") as? Int ?? 0
                let patch = vDict.caseInsensitiveValue(forKey: "PatchVersion") as? Int ?? 0
                version = "\(major).\(minor).\(patch)"
            }
            
            if let mAuthor = json.caseInsensitiveValue(forKey: "Author") as? String { author = mAuthor }
            if let mDesc = json.caseInsensitiveValue(forKey: "Description") as? String { description = mDesc }
            
            if let deps = json.caseInsensitiveValue(forKey: "Dependencies") as? [[String: Any]] {
                for dep in deps {
                    if let depId = dep.caseInsensitiveValue(forKey: "UniqueID") as? String {
                        let isReq = dep.caseInsensitiveValue(forKey: "IsRequired") as? Bool ?? true
                        dependencies.append(ModDependency(uniqueId: depId, isRequired: isReq))
                    }
                }
            }
            
            if let updateKeys = json.caseInsensitiveValue(forKey: "UpdateKeys") as? [String] {
                for key in updateKeys {
                    if key.lowercased().hasPrefix("nexus:") {
                        let id = key.replacingOccurrences(of: "nexus:", with: "", options: .caseInsensitive)
                        nexusUrl = "https://www.nexusmods.com/stardewvalley/mods/\(id.trimmingCharacters(in: .whitespacesAndNewlines))"
                        break
                    }
                }
            }
        }
        
        let finalTag = customTags[uniqueId] ?? ModItem.inferTag(name: name, uniqueId: uniqueId, description: description)
        
        var installDate: Date? = nil
        var lastModifiedDate: Date? = nil
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            installDate = attributes[.creationDate] as? Date
            lastModifiedDate = attributes[.modificationDate] as? Date
        } catch {
            print("Could not get attributes for mod path: \(path) - \(error)")
        }
        
        return ModItem(
            uniqueId: uniqueId,
            name: name,
            folderName: relativePath.isEmpty ? (path as NSString).lastPathComponent : relativePath,
            version: version,
            author: author,
            description: description,
            nexusUrl: nexusUrl,
            isEnabled: isEnabled,
            dependencies: dependencies,
            modTag: finalTag,
            installDate: installDate,
            lastModifiedDate: lastModifiedDate
        )
    }
}

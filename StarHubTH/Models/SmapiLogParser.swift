import Foundation

struct SmapiLogParserResult {
    let outOfDateMods: [ModUpdateInfo]
    let errors: [String]
}

struct SmapiLogParser {
    static func parse(logContent: String) -> SmapiLogParserResult {
        var updates: [ModUpdateInfo] = []
        var errors: [String] = []
        
        let lines = logContent.components(separatedBy: .newlines)
        var isParsingUpdates = false
        var isParsingErrors = false
        
        for line in lines {
            // Check for Updates
            if line.contains("You can update") {
                isParsingUpdates = true
                continue
            }
            if isParsingUpdates {
                if line.contains("ALERT SMAPI") && line.contains("https://") {
                    // Example: [12:00:00 ALERT SMAPI]    Content Patcher 2.0.0: https://smapi.io/mods#Content_Patcher
                    let parts = line.components(separatedBy: "ALERT SMAPI]")
                    if parts.count > 1 {
                        let infoString = parts[1].trimmingCharacters(in: .whitespaces)
                        let split = infoString.components(separatedBy: ": https://")
                        if split.count == 2 {
                            let nameAndVersion = split[0]
                            let url = "https://" + split[1]
                            
                            // Naive split by last space for version
                            let nvSplit = nameAndVersion.components(separatedBy: " ")
                            let version = nvSplit.last ?? ""
                            let name = nvSplit.dropLast().joined(separator: " ")
                            
                            updates.append(ModUpdateInfo(name: name, version: version, url: url))
                        }
                    }
                } else if !line.contains("ALERT SMAPI") {
                    // Reached end of alert block
                    isParsingUpdates = false
                }
            }
            
            // Check for Errors (Skipped mods or general red text)
            if line.contains("ERROR SMAPI") {
                if line.contains("Skipped mods") {
                    isParsingErrors = true
                    continue
                }
                
                if isParsingErrors {
                    if line.contains("-------------------------") || line.contains("These mods could not be added") {
                        continue
                    }
                    if line.contains("WARN ") || line.contains("INFO ") || line.contains("TRACE ") || line.contains("DEBUG ") {
                        isParsingErrors = false
                    } else {
                        let parts = line.components(separatedBy: "ERROR SMAPI]")
                        if parts.count > 1 {
                            let msg = parts[1].trimmingCharacters(in: .whitespaces)
                            if !msg.isEmpty {
                                errors.append(msg)
                            }
                        }
                    }
                } else {
                    // General error line not in "Skipped mods"
                    if !line.contains("Skipped mods") && !line.contains("-------------------------") {
                        let parts = line.components(separatedBy: "ERROR")
                        if parts.count > 1 {
                            let msg = parts[1].trimmingCharacters(in: .whitespaces)
                            // Filter out known empty or structural lines
                            if msg.hasPrefix("SMAPI]") {
                                let actualMsg = msg.replacingOccurrences(of: "SMAPI]", with: "").trimmingCharacters(in: .whitespaces)
                                if !actualMsg.isEmpty {
                                    errors.append(actualMsg)
                                }
                            }
                        }
                    }
                }
            } else if isParsingErrors && (line.contains("WARN ") || line.contains("INFO ") || line.contains("TRACE ") || line.contains("DEBUG ")) {
                isParsingErrors = false
            }
        }
        
        // Remove duplicates and limit error messages
        let uniqueErrors = Array(NSOrderedSet(array: errors)).prefix(10).map { $0 as! String }
        
        return SmapiLogParserResult(outOfDateMods: updates, errors: uniqueErrors)
    }
}

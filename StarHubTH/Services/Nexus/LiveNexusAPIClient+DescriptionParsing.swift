import Foundation

/// Formats a Nexus mod's HTML/BBCode description into basic Markdown, extracting images
/// and spoiler blocks as structured tokens a view can render individually (§ file-size
/// convention split, see LiveNexusAPIClient.swift's header comment). Self-contained text
/// formatting — doesn't touch any networking state, hence its own file.
extension LiveNexusAPIClient {
    enum DescriptionBlock: Hashable {
        case text(String)
        case image(URL)
        case spoiler(title: String, content: String)
    }

    // Helper: format HTML and BBCode into basic Markdown and extract images & spoilers
    static func parseBlocks(_ str: String) -> [DescriptionBlock] {
        var formatted = str

        // 1. Basic HTML Entities
        formatted = formatted.replacingOccurrences(of: "&nbsp;", with: " ")
                             .replacingOccurrences(of: "&amp;", with: "&")
                             .replacingOccurrences(of: "&lt;", with: "<")
                             .replacingOccurrences(of: "&gt;", with: ">")
                             .replacingOccurrences(of: "&quot;", with: "\"")

        // 2. Convert <br> and HTML block tags to newlines so text doesn't run together
        formatted = formatted.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)</?(?:p|div|h[1-6]|li|tr|blockquote)\\b[^>]*>", with: "\n", options: .regularExpression)

        // 3. Strip all other HTML tags
        formatted = formatted.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 4. Convert BBCode to Markdown using (?s) to match across newlines
        // Note: We use \s* inside the capture groups so that leading/trailing newlines don't break Markdown rendering (e.g. ** text ** is invalid Markdown)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[b\\]\\s*(.*?)\\s*\\[/b\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[i\\]\\s*(.*?)\\s*\\[/i\\]", with: "*$1*", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[s\\]\\s*(.*?)\\s*\\[/s\\]", with: "~~$1~~", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[u\\]\\s*(.*?)\\s*\\[/u\\]", with: "*$1*", options: [.regularExpression, .caseInsensitive])

        // Headers (Size tags and heading tags)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[size=[^\\]]+\\]\\s*(.*?)\\s*\\[/size\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[heading[=\\d]*\\]\\s*(.*?)\\s*\\[/heading\\]", with: "**$1**", options: [.regularExpression, .caseInsensitive])

        // Lists
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/?list(?:=[^\\]]+)?\\]", with: "\n", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[\\*\\]", with: "\n- ", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[li\\]", with: "\n- ", options: .regularExpression)
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/li\\]", with: "", options: .regularExpression)

        // Links
        formatted = formatted.replacingOccurrences(of: "(?s)\\[url=(.*?)\\]\\s*(.*?)\\s*\\[/url\\]", with: "[$2]($1)", options: [.regularExpression, .caseInsensitive])
        formatted = formatted.replacingOccurrences(of: "(?s)\\[url\\]\\s*(.*?)\\s*\\[/url\\]", with: "[$1]($1)", options: [.regularExpression, .caseInsensitive])

        // Horizontal Rules
        formatted = formatted.replacingOccurrences(of: "(?i)\\[/?(?:line|hr)\\]", with: "\n---\n", options: .regularExpression)

        // 5. Strip remaining formatting BBCode tags (keeping their inner content)
        formatted = formatted.replacingOccurrences(of: "(?s)\\[/?(?:color|center|left|right|font|align|quote|sub|sup|code)(?:=[^\\]]+)?\\]", with: "", options: [.regularExpression, .caseInsensitive])

        // 6. Tokenize by [img] and [spoiler] tags
        var blocks: [DescriptionBlock] = []
        let combinedPattern = "(?s)(\\[img\\](.*?)\\[/img\\]|\\[spoiler(?:=(.*?))?\\](.*?)\\[/spoiler\\])"
        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive) else {
            return [.text(formatted.trimmingCharacters(in: .whitespacesAndNewlines))]
        }

        let nsString = formatted as NSString
        let matches = regex.matches(in: formatted, range: NSRange(location: 0, length: nsString.length))

        var lastEnd = 0
        for match in matches {
            let textRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let textStr = nsString.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !textStr.isEmpty {
                blocks.append(.text(textStr))
            }

            let fullMatch = nsString.substring(with: match.range)
            if fullMatch.lowercased().hasPrefix("[img]") {
                let imgUrlRange = match.range(at: 2)
                if imgUrlRange.location != NSNotFound {
                    let imgUrlStr = nsString.substring(with: imgUrlRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: imgUrlStr) {
                        blocks.append(.image(url))
                    }
                }
            } else if fullMatch.lowercased().hasPrefix("[spoiler") {
                let titleRange = match.range(at: 3)
                let contentRange = match.range(at: 4)

                var titleStr = "Spoiler"
                if titleRange.location != NSNotFound {
                    let extracted = nsString.substring(with: titleRange).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty {
                        titleStr = extracted
                    }
                }

                var contentStr = ""
                if contentRange.location != NSNotFound {
                    contentStr = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                blocks.append(.spoiler(title: titleStr, content: contentStr))
            }

            lastEnd = match.range.location + match.range.length
        }

        let finalText = nsString.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalText.isEmpty {
            blocks.append(.text(finalText))
        }

        return blocks
    }
}

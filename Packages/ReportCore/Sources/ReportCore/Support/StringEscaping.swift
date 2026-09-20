import Foundation

public extension String {
    /// Escapes the five characters that matter inside HTML text and attributes.
    var htmlEscaped: String {
        var output = ""
        output.reserveCapacity(count)
        for character in self {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\"": output += "&quot;"
            case "'": output += "&#39;"
            default: output.append(character)
            }
        }
        return output
    }

    /// Escapes characters that would otherwise be read as Markdown syntax.
    var markdownEscaped: String {
        var output = ""
        output.reserveCapacity(count)
        for character in self {
            if "\\`*_{}[]#+|".contains(character) {
                output.append("\\")
            }
            output.append(character)
        }
        return output
    }

    /// A short, filesystem-safe version of the string, e.g. for export file names.
    var fileNameSafe: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = String(unicodeScalars.filter { allowed.contains($0) }.map(Character.init))
        let words = cleaned.split(whereSeparator: { $0 == " " || $0 == "-" }).map(String.init)
        let joined = words.joined(separator: "-")
        return joined.isEmpty ? "card" : String(joined.prefix(60))
    }
}

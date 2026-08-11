import Foundation

enum LanguageCompositionAnalyzer {
    private enum ScriptGroup {
        case han
        case hiragana
        case katakana
        case hangul
        case latin
        case cyrillic
        case arabic
        case thai
        case other
    }

    static func shouldReturnOriginal(
        _ text: String,
        targetIdentifier: String,
        detectedSourceIdentifier: String?
    ) -> Bool {
        guard
            let detectedSourceIdentifier,
            languagesAreEquivalent(detectedSourceIdentifier, targetIdentifier)
        else {
            return false
        }

        let counts = scriptCounts(in: text)
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return true }

        let allowed = allowedScripts(for: targetIdentifier)
        let foreignCount = counts.reduce(into: 0) { result, entry in
            if !allowed.contains(entry.key) {
                result += entry.value
            }
        }

        // Ignore a short product name or acronym inside an otherwise single-language
        // passage, but route meaningful foreign-language spans through Translation.
        let foreignRatio = Double(foreignCount) / Double(total)
        let hasMeaningfulForeignSpan = foreignCount >= 4 && foreignRatio >= 0.08
        return !hasMeaningfulForeignSpan
    }

    static func hasMeaningfulMixedScripts(_ text: String, targetIdentifier: String) -> Bool {
        let counts = scriptCounts(in: text)
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return false }

        let allowed = allowedScripts(for: targetIdentifier)
        let foreignCount = counts.reduce(into: 0) { result, entry in
            if !allowed.contains(entry.key) {
                result += entry.value
            }
        }
        return foreignCount >= 4 && Double(foreignCount) / Double(total) >= 0.08
    }

    private static func languagesAreEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.lowercased()
        let right = rhs.lowercased()

        if left.hasPrefix("zh-") || right.hasPrefix("zh-") {
            return left == right || left == "zh" || right == "zh"
        }

        return left.split(separator: "-").first == right.split(separator: "-").first
    }

    private static func allowedScripts(for languageIdentifier: String) -> Set<ScriptGroup> {
        let language = languageIdentifier.lowercased().split(separator: "-").first.map(String.init) ?? ""
        switch language {
        case "zh":
            return [.han]
        case "ja":
            return [.han, .hiragana, .katakana]
        case "ko":
            return [.hangul, .han]
        case "en", "fr", "de", "es", "it", "pt", "nl", "sv", "da", "no", "fi", "id", "ms", "vi", "pl", "tr":
            return [.latin]
        case "ru", "uk":
            return [.cyrillic]
        case "ar":
            return [.arabic]
        case "th":
            return [.thai]
        default:
            return [.other]
        }
    }

    private static func scriptCounts(in text: String) -> [ScriptGroup: Int] {
        var counts: [ScriptGroup: Int] = [:]
        for scalar in text.unicodeScalars {
            guard let group = scriptGroup(for: scalar) else { continue }
            counts[group, default: 0] += 1
        }
        return counts
    }

    private static func scriptGroup(for scalar: Unicode.Scalar) -> ScriptGroup? {
        let value = scalar.value
        switch value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0x20000...0x2FA1F:
            return .han
        case 0x3040...0x309F:
            return .hiragana
        case 0x30A0...0x30FF, 0x31F0...0x31FF, 0xFF66...0xFF9D:
            return .katakana
        case 0x1100...0x11FF, 0x3130...0x318F, 0xAC00...0xD7AF:
            return .hangul
        case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F, 0x1E00...0x1EFF:
            return .latin
        case 0x0400...0x052F:
            return .cyrillic
        case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF:
            return .arabic
        case 0x0E00...0x0E7F:
            return .thai
        default:
            return scalar.properties.isAlphabetic ? .other : nil
        }
    }
}

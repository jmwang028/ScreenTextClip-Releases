import Foundation

enum InterfaceLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}

enum InterfaceText {
    private static let languageKey = "ScreenTextClip.interfaceLanguage"

    static var language: InterfaceLanguage {
        get {
            guard
                let value = UserDefaults.standard.string(forKey: languageKey),
                let language = InterfaceLanguage(rawValue: value)
            else {
                return .english
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }

    static func localized(_ english: String, _ simplifiedChinese: String) -> String {
        language == .simplifiedChinese ? simplifiedChinese : english
    }
}

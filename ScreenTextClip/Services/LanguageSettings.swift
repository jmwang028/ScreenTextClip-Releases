import Foundation
import Translation
import Vision

struct AppLanguage: Hashable {
    let id: String
    let translationIdentifier: String
    let ocrIdentifier: String
    let displayName: String
    let isBuiltIn: Bool

    static let simplifiedChinese = AppLanguage(
        id: "zh-Hans",
        translationIdentifier: "zh-Hans",
        ocrIdentifier: "zh-Hans",
        displayName: "简体中文",
        isBuiltIn: true
    )
    static let english = AppLanguage(
        id: "en",
        translationIdentifier: "en",
        ocrIdentifier: "en-US",
        displayName: "English",
        isBuiltIn: true
    )
    static let japanese = AppLanguage(
        id: "ja",
        translationIdentifier: "ja",
        ocrIdentifier: "ja-JP",
        displayName: "日本語",
        isBuiltIn: true
    )
    static let korean = AppLanguage(
        id: "ko",
        translationIdentifier: "ko",
        ocrIdentifier: "ko-KR",
        displayName: "한국어",
        isBuiltIn: true
    )

    static let builtInLanguages = [simplifiedChinese, english, japanese, korean]
}

struct LanguageConfiguration {
    let recognitionLanguages: [String]
    let targetLanguage: AppLanguage
}

final class LanguageSettings {
    private let defaults: UserDefaults
    private let catalogService: LanguageCatalogService
    private let customLanguageIDsKey = "customLanguageIdentifiers"
    private let targetLanguageKey = "translationTargetLanguage"

    private(set) var availableLanguages = AppLanguage.builtInLanguages

    init(
        defaults: UserDefaults = .standard,
        catalogService: LanguageCatalogService = LanguageCatalogService()
    ) {
        self.defaults = defaults
        self.catalogService = catalogService
    }

    var enabledLanguages: [AppLanguage] {
        let availableByID = Dictionary(uniqueKeysWithValues: availableLanguages.map { ($0.id, $0) })
        let customLanguages = customLanguageIDs
            .compactMap { availableByID[$0] }
            .filter { !$0.isBuiltIn }
            .sorted(by: Self.sortByDisplayName)
        return AppLanguage.builtInLanguages + customLanguages
    }

    var targetLanguage: AppLanguage {
        let targetID = defaults.string(forKey: targetLanguageKey) ?? AppLanguage.simplifiedChinese.id
        return enabledLanguages.first { $0.id == targetID } ?? .simplifiedChinese
    }

    var configuration: LanguageConfiguration {
        LanguageConfiguration(
            recognitionLanguages: enabledLanguages.map(\.ocrIdentifier),
            targetLanguage: targetLanguage
        )
    }

    func loadAvailableLanguages(completion: @escaping (Result<Void, Error>) -> Void) {
        guard #available(macOS 15.0, *) else {
            completion(.success(()))
            return
        }

        catalogService.load { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let languages):
                self.availableLanguages = languages
                self.removeUnavailableSelections()
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func setTargetLanguage(id: String) {
        guard enabledLanguages.contains(where: { $0.id == id }) else { return }
        defaults.set(id, forKey: targetLanguageKey)
    }

    func setLanguage(id: String, enabled: Bool) {
        guard let language = availableLanguages.first(where: { $0.id == id }), !language.isBuiltIn else {
            return
        }

        var ids = Set(customLanguageIDs)
        if enabled {
            ids.insert(id)
        } else {
            ids.remove(id)
            if targetLanguage.id == id {
                defaults.set(AppLanguage.simplifiedChinese.id, forKey: targetLanguageKey)
            }
        }
        customLanguageIDs = Array(ids)
    }

    func isLanguageEnabled(id: String) -> Bool {
        AppLanguage.builtInLanguages.contains(where: { $0.id == id }) || customLanguageIDs.contains(id)
    }

    private var customLanguageIDs: [String] {
        get { defaults.stringArray(forKey: customLanguageIDsKey) ?? [] }
        set { defaults.set(newValue.sorted(), forKey: customLanguageIDsKey) }
    }

    private func removeUnavailableSelections() {
        let availableIDs = Set(availableLanguages.map(\.id))
        customLanguageIDs = customLanguageIDs.filter { availableIDs.contains($0) }

        let storedTargetID = defaults.string(forKey: targetLanguageKey)
        if let storedTargetID, !enabledLanguages.contains(where: { $0.id == storedTargetID }) {
            defaults.set(AppLanguage.simplifiedChinese.id, forKey: targetLanguageKey)
        }
    }

    private static func sortByDisplayName(_ lhs: AppLanguage, _ rhs: AppLanguage) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}

final class LanguageCatalogService {
    func load(completion: @escaping (Result<[AppLanguage], Error>) -> Void) {
        guard #available(macOS 15.0, *) else {
            completion(.success(AppLanguage.builtInLanguages))
            return
        }

        Task {
            do {
                let translationLanguages = await LanguageAvailability().supportedLanguages
                let request = VNRecognizeTextRequest()
                request.revision = VNRecognizeTextRequest.currentRevision
                request.recognitionLevel = .accurate
                let visionIdentifiers = try request.supportedRecognitionLanguages()
                let languages = Self.intersection(
                    translationLanguages: translationLanguages,
                    visionIdentifiers: visionIdentifiers
                )
                DispatchQueue.main.async {
                    completion(.success(languages))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    @available(macOS 15.0, *)
    private static func intersection(
        translationLanguages: [Locale.Language],
        visionIdentifiers: [String]
    ) -> [AppLanguage] {
        let visionLanguages = visionIdentifiers.map(VisionLanguage.init)
        let builtInIDs = Set(AppLanguage.builtInLanguages.map(\.id))
        var seenIDs = builtInIDs
        var additionalLanguages: [AppLanguage] = []

        for translationLanguage in translationLanguages.sorted(by: { $0.maximalIdentifier < $1.maximalIdentifier }) {
            guard
                let languageCode = translationLanguage.languageCode?.identifier,
                let id = stableIdentifier(for: translationLanguage),
                !seenIDs.contains(id)
            else {
                continue
            }

            let script = translationLanguage.script?.identifier
            let candidates = visionLanguages.filter { $0.languageCode == languageCode }
            let visionLanguage = candidates.first { script != nil && $0.script == script } ?? candidates.first
            guard let visionLanguage else { continue }

            seenIDs.insert(id)
            additionalLanguages.append(AppLanguage(
                id: id,
                translationIdentifier: id,
                ocrIdentifier: visionLanguage.identifier,
                displayName: displayName(for: translationLanguage, id: id),
                isBuiltIn: false
            ))
        }

        return AppLanguage.builtInLanguages + additionalLanguages.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    @available(macOS 15.0, *)
    private static func stableIdentifier(for language: Locale.Language) -> String? {
        guard let languageCode = language.languageCode?.identifier else { return nil }
        if languageCode == "zh", let script = language.script?.identifier {
            return "zh-\(script)"
        }
        return languageCode
    }

    @available(macOS 15.0, *)
    private static func displayName(for language: Locale.Language, id: String) -> String {
        switch id {
        case "zh-Hans":
            return "简体中文"
        case "zh-Hant":
            return "繁體中文"
        default:
            guard let languageCode = language.languageCode?.identifier else { return id }
            let locale = Locale(identifier: language.maximalIdentifier)
            return locale.localizedString(forLanguageCode: languageCode) ?? id
        }
    }
}

private struct VisionLanguage {
    let identifier: String
    let languageCode: String?
    let script: String?

    init(identifier: String) {
        let language = Locale.Language(identifier: identifier)
        self.identifier = identifier
        self.languageCode = language.languageCode?.identifier
        self.script = language.script?.identifier
    }
}

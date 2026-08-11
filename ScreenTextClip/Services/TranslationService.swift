import AppKit
import CoreFoundation
import NaturalLanguage
import SwiftUI
import Translation

enum TranslationServiceError: LocalizedError {
    case unavailable
    case unsupportedLanguagePairing

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return InterfaceText.localized(
                "Apple Translation requires macOS 15 or later.",
                "Apple 翻译需要 macOS 15 或更高版本。"
            )
        case .unsupportedLanguagePairing:
            return InterfaceText.localized(
                "Apple Translation does not support this language pair.",
                "Apple 翻译不支持此语言组合。"
            )
        }
    }
}

final class TranslationService: @unchecked Sendable {
    private var hostingView: NSView?
    private var activeRequestID: UUID?
    private var preflightTask: Task<Void, Never>?

    func translate(
        _ text: String,
        to targetLanguage: AppLanguage,
        hostedIn container: NSView,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        cancel()

        guard #available(macOS 15.0, *) else {
            completion(.failure(TranslationServiceError.unavailable))
            return
        }

        let requestID = UUID()
        activeRequestID = requestID

        preflightTask = Task { [weak self, weak container] in
            let route = await TranslationService.route(
                sourceText: text,
                targetIdentifier: targetLanguage.translationIdentifier
            )

            DispatchQueue.main.async {
                guard
                    let self,
                    let container,
                    self.activeRequestID == requestID
                else {
                    return
                }

                self.preflightTask = nil
                switch route {
                case .local(let translatedText):
                    self.activeRequestID = nil
                    completion(.success(translatedText))
                case .apple(let sourceIdentifier, let shouldPrepare):
                    self.attachBridge(
                        sourceText: text,
                        sourceIdentifier: sourceIdentifier,
                        targetIdentifier: targetLanguage.translationIdentifier,
                        shouldPrepare: shouldPrepare,
                        container: container,
                        requestID: requestID,
                        completion: completion
                    )
                }
            }
        }
    }

    @available(macOS 15.0, *)
    private func attachBridge(
        sourceText: String,
        sourceIdentifier: String?,
        targetIdentifier: String,
        shouldPrepare: Bool,
        container: NSView,
        requestID: UUID,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let bridge = TranslationBridgeView(
            sourceText: sourceText,
            sourceIdentifier: sourceIdentifier,
            targetIdentifier: targetIdentifier,
            shouldPrepare: shouldPrepare
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.activeRequestID == requestID else { return }
                self.hostingView?.removeFromSuperview()
                self.hostingView = nil
                self.activeRequestID = nil
                completion(result)
            }
        }

        let hostingView = NSHostingView(rootView: AnyView(bridge))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hostingView.widthAnchor.constraint(equalToConstant: 1),
            hostingView.heightAnchor.constraint(equalToConstant: 1)
        ])
        self.hostingView = hostingView
    }

    func cancel() {
        preflightTask?.cancel()
        preflightTask = nil
        activeRequestID = nil
        hostingView?.removeFromSuperview()
        hostingView = nil
    }

    @available(macOS 15.0, *)
    private static func route(
        sourceText: String,
        targetIdentifier: String
    ) async -> TranslationRoute {
        let targetLanguage = Locale.Language(identifier: targetIdentifier)
        let sourceIdentifier = detectedSourceIdentifier(for: sourceText)
        let isMeaningfullyMixed = LanguageCompositionAnalyzer.hasMeaningfulMixedScripts(
            sourceText,
            targetIdentifier: targetIdentifier
        )

        if LanguageCompositionAnalyzer.shouldReturnOriginal(
            sourceText,
            targetIdentifier: targetIdentifier,
            detectedSourceIdentifier: sourceIdentifier
        ) {
            return .local(sourceText)
        }

        do {
            let status = try await LanguageAvailability().status(
                for: sourceText,
                to: targetLanguage
            )
            DebugLogger.log(
                "preflight source=\(sourceIdentifier ?? "unknown") target=\(targetIdentifier) status=\(status)",
                category: "Translation"
            )

            if status == .unsupported,
               !isMeaningfullyMixed,
               let convertedText = localChineseConversion(
                   sourceText,
                   sourceIdentifier: sourceIdentifier,
                   targetIdentifier: targetIdentifier
               ) {
                return .local(convertedText)
            }

            // A concrete source is only used to let macOS prepare a missing language
            // model. Installed mixed-language text keeps the automatic-source path.
            if status == .supported, let sourceIdentifier {
                DebugLogger.log(
                    "preparing source model source=\(sourceIdentifier) mixed=\(isMeaningfullyMixed)",
                    category: "Translation"
                )
                return .apple(sourceIdentifier: sourceIdentifier, shouldPrepare: true)
            }
        } catch {
            DebugLogger.log(
                "translation preflight failed error=\(error.localizedDescription)",
                category: "Translation"
            )
        }

        return .apple(sourceIdentifier: nil, shouldPrepare: false)
    }

    private static func detectedSourceIdentifier(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func localChineseConversion(
        _ text: String,
        sourceIdentifier: String?,
        targetIdentifier: String
    ) -> String? {
        let transform: String
        switch (sourceIdentifier, targetIdentifier) {
        case ("zh-Hant", "zh-Hans"):
            transform = "Hant-Hans"
        case ("zh-Hans", "zh-Hant"):
            transform = "Hans-Hant"
        default:
            return nil
        }

        let convertedText = NSMutableString(string: text)
        guard CFStringTransform(convertedText, nil, transform as CFString, false) else {
            return nil
        }
        return convertedText as String
    }
}

private enum TranslationRoute {
    case apple(sourceIdentifier: String?, shouldPrepare: Bool)
    case local(String)
}

@available(macOS 15.0, *)
private struct TranslationBridgeView: View {
    let sourceText: String
    let configuration: TranslationSession.Configuration
    let completion: (Result<String, Error>) -> Void

    init(
        sourceText: String,
        sourceIdentifier: String?,
        targetIdentifier: String,
        shouldPrepare: Bool,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        self.sourceText = sourceText
        self.configuration = TranslationSession.Configuration(
            source: sourceIdentifier.map(Locale.Language.init(identifier:)),
            target: Locale.Language(identifier: targetIdentifier)
        )
        self.shouldPrepare = shouldPrepare
        self.completion = completion
    }

    let shouldPrepare: Bool

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(configuration) { session in
                do {
                    if shouldPrepare {
                        try await session.prepareTranslation()
                    }
                    let response = try await session.translate(sourceText)
                    completion(.success(response.targetText))
                } catch {
                    if TranslationError.unsupportedLanguagePairing ~= error {
                        completion(.failure(TranslationServiceError.unsupportedLanguagePairing))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
    }
}

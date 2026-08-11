import AppKit

final class CaptureCoordinator {
    private let permissionService = PermissionService()
    private let overlay = MultiDisplaySelectionOverlay()
    private let screenCaptureService = ScreenCaptureService()
    private let ocrService = OCRService()
    private let clipboardService = ClipboardService()
    private let translationService = TranslationService()
    private let languageSettings: LanguageSettings
    private lazy var translationPanelController: TranslationResultPanelController = {
        let controller = TranslationResultPanelController()
        controller.onClose = { [weak self] in
            self?.translationService.cancel()
        }
        return controller
    }()

    private var isCapturing = false

    init(languageSettings: LanguageSettings) {
        self.languageSettings = languageSettings
    }

    func start() {
        DebugLogger.log("start requested isCapturing=\(isCapturing)", category: "CaptureCoordinator")
        guard !isCapturing else { return }

        translationPanelController.close()
        isCapturing = true
        let languageConfiguration = languageSettings.configuration
        DebugLogger.log(
            "capture languages=\(languageConfiguration.recognitionLanguages.joined(separator: ",")) target=\(languageConfiguration.targetLanguage.translationIdentifier)",
            category: "Languages"
        )
        DebugLogger.log("begin overlay selection", category: "CaptureCoordinator")

        overlay.beginSelection { [weak self] result in
            guard let self else { return }

            guard let result else {
                DebugLogger.log("selection cancelled", category: "CaptureCoordinator")
                self.isCapturing = false
                return
            }

            DebugLogger.log("selection completed displayID=\(result.displayID) rect=\(result.screenLocalRect)", category: "CaptureCoordinator")

            guard result.screenLocalRect.width > 0, result.screenLocalRect.height > 0 else {
                DebugLogger.log("selection rect is empty after coordinate conversion", category: "CaptureCoordinator")
                self.isCapturing = false
                NotificationService.show(InterfaceText.localized("Capture cancelled", "已取消截取"))
                return
            }

            guard self.permissionService.ensureScreenRecordingPermission() else {
                DebugLogger.log("screen recording permission denied", category: "CaptureCoordinator")
                self.isCapturing = false
                NotificationService.showPermissionGuidance()
                return
            }

            DebugLogger.log("screen recording permission ok, starting ScreenCaptureKit", category: "CaptureCoordinator")
            self.screenCaptureService.capture(result) { [weak self] image in
                guard let self else { return }

                guard let image else {
                    DebugLogger.log("ScreenCaptureKit returned nil image", category: "CaptureCoordinator")
                    self.isCapturing = false
                    NotificationService.show(InterfaceText.localized("Capture failed", "截取失败"))
                    return
                }

                self.recognizeAndCopyText(
                    from: image,
                    selection: result,
                    languageConfiguration: languageConfiguration
                )
            }
        }
    }

    private func recognizeAndCopyText(
        from image: NSImage,
        selection: SelectionResult,
        languageConfiguration: LanguageConfiguration
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let recognition = self.ocrService.recognizeText(
                in: image,
                recognitionLanguages: languageConfiguration.recognitionLanguages
            )
            let text = recognition.text.trimmingCharacters(in: .whitespacesAndNewlines)
            DebugLogger.log(
                "ocr finished characters=\(text.count) confidence=\(String(format: "%.3f", recognition.confidence)) retried=\(recognition.didRetry)",
                category: "CaptureCoordinator"
            )

            DispatchQueue.main.async {
                self.isCapturing = false

                guard !text.isEmpty else {
                    NotificationService.show(InterfaceText.localized("No text found", "未识别到文字"))
                    return
                }

                self.clipboardService.copy(text)
                NotificationService.show(InterfaceText.localized(
                    "Copied \(text.count) characters",
                    "已复制 \(text.count) 个字符"
                ))
                self.translate(
                    text,
                    selection: selection,
                    targetLanguage: languageConfiguration.targetLanguage
                )
            }
        }
    }

    private func translate(
        _ text: String,
        selection: SelectionResult,
        targetLanguage: AppLanguage
    ) {
        let bridgeContainer = translationPanelController.showLoading(
            targetLanguage: targetLanguage,
            selection: selection
        )

        DebugLogger.log("translation started target=\(targetLanguage.translationIdentifier)", category: "CaptureCoordinator")
        translationService.translate(text, to: targetLanguage, hostedIn: bridgeContainer) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let translatedText):
                let cleanedText = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                DebugLogger.log("translation finished characters=\(cleanedText.count)", category: "CaptureCoordinator")
                guard !cleanedText.isEmpty else {
                    self.translationPanelController.showError(InterfaceText.localized(
                        "No translated text was returned.",
                        "没有返回翻译结果。"
                    ))
                    return
                }
                self.translationPanelController.showTranslation(cleanedText)

            case .failure(let error):
                DebugLogger.log("translation failed error=\(error.localizedDescription)", category: "CaptureCoordinator")
                self.translationPanelController.showError(self.translationErrorMessage(for: error))
            }
        }
    }

    private func translationErrorMessage(for error: Error) -> String {
        if error is TranslationServiceError {
            return error.localizedDescription
        }
        return InterfaceText.localized(
            "Translation could not be completed. Try again after the required language download finishes.",
            "无法完成翻译。请在所需语言下载完成后重试。"
        )
    }
}

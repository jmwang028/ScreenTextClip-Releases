import AppKit
import XCTest

final class LanguageCompositionAnalyzerTests: XCTestCase {
    func testPureTargetLanguageCanReturnOriginal() {
        XCTAssertTrue(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "这是一段纯中文内容，用于测试本地识别。",
            targetIdentifier: "zh-Hans",
            detectedSourceIdentifier: "zh-Hans"
        ))
        XCTAssertTrue(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "This paragraph is already written in English.",
            targetIdentifier: "en",
            detectedSourceIdentifier: "en"
        ))
    }

    func testMixedTargetLanguageDoesNotReturnWholeOriginal() {
        XCTAssertFalse(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "这段文字 includes several English words that still need translation。",
            targetIdentifier: "zh-Hans",
            detectedSourceIdentifier: "zh-Hans"
        ))
        XCTAssertFalse(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "This paragraph 仍然包含需要翻译的中文内容。",
            targetIdentifier: "en",
            detectedSourceIdentifier: "en"
        ))
    }

    func testTraditionalChineseStillRoutesToSimplifiedConversion() {
        XCTAssertFalse(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "這是一段繁體中文內容。",
            targetIdentifier: "zh-Hans",
            detectedSourceIdentifier: "zh-Hant"
        ))
        XCTAssertFalse(LanguageCompositionAnalyzer.shouldReturnOriginal(
            "這段內容 includes English words that require translation。",
            targetIdentifier: "zh-Hans",
            detectedSourceIdentifier: "zh-Hant"
        ))
    }
}

final class OCRTextLayoutTests: XCTestCase {
    func testCJKFragmentsDoNotReceiveMechanicalSpaces() {
        let items = [
            item("屏幕", x: 0.10, y: 0.70, width: 0.12, height: 0.08),
            item("取词", x: 0.23, y: 0.70, width: 0.12, height: 0.08),
            item("テスト", x: 0.36, y: 0.70, width: 0.14, height: 0.08),
            item("완료", x: 0.51, y: 0.70, width: 0.12, height: 0.08)
        ]

        XCTAssertEqual(OCRTextLayout.orderedText(from: items), "屏幕取词テスト완료")
    }

    func testCJKPunctuationDoesNotCreateSpaces() {
        let items = [
            item("识别完成，", x: 0.10, y: 0.70, width: 0.18, height: 0.08),
            item("继续翻译", x: 0.29, y: 0.70, width: 0.18, height: 0.08),
            item("（本地）", x: 0.48, y: 0.70, width: 0.16, height: 0.08)
        ]

        XCTAssertEqual(OCRTextLayout.orderedText(from: items), "识别完成，继续翻译（本地）")
    }

    func testEnglishFragmentsKeepWordSpaces() {
        let items = [
            item("local", x: 0.10, y: 0.70, width: 0.12, height: 0.08),
            item("OCR", x: 0.23, y: 0.70, width: 0.09, height: 0.08)
        ]

        XCTAssertEqual(OCRTextLayout.orderedText(from: items), "local OCR")
    }

    func testVerticalOverlapMergesDifferentFontSizesOnOneLine() {
        let items = [
            item("Large", x: 0.10, y: 0.62, width: 0.20, height: 0.16),
            item("caption", x: 0.31, y: 0.65, width: 0.18, height: 0.08),
            item("Next line", x: 0.10, y: 0.46, width: 0.25, height: 0.08)
        ]

        XCTAssertEqual(OCRTextLayout.orderedText(from: items), "Large caption\nNext line")
    }

    func testObviousTwoColumnTextUsesColumnMajorOrder() {
        let items = [
            item("Left one", x: 0.06, y: 0.76, width: 0.25, height: 0.07),
            item("Right one", x: 0.60, y: 0.76, width: 0.27, height: 0.07),
            item("Left two", x: 0.06, y: 0.62, width: 0.25, height: 0.07),
            item("Right two", x: 0.60, y: 0.62, width: 0.27, height: 0.07)
        ]

        XCTAssertEqual(
            OCRTextLayout.orderedText(from: items),
            "Left one\nLeft two\nRight one\nRight two"
        )
    }

    private func item(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat
    ) -> OCRTextItem {
        OCRTextItem(
            text: text,
            box: CGRect(x: x, y: y, width: width, height: height),
            confidence: 0.9
        )
    }
}

final class OCRGeneratedFixtureTests: XCTestCase {
    private let languages = ["en-US", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR"]

    func testEnglishParagraph() {
        let result = assertRecognizes(
            fixture: image(blocks: [
                block("ScreenTextClip uses local OCR.", x: 40, y: 115, width: 720, height: 42, size: 26),
                block("Clear text should stay on the fast path.", x: 40, y: 65, width: 720, height: 42, size: 22)
            ]),
            contains: ["screentextclip", "localocr"]
        )
        XCTAssertFalse(result.didRetry, "Expected a clear paragraph to stay on the single-pass fast path")
    }

    func testSimplifiedChineseSmallText() {
        assertRecognizes(
            fixture: image(blocks: [
                block("屏幕取词采用本地识别，小字体也应保持清晰。", x: 30, y: 72, width: 760, height: 40, size: 15)
            ]),
            contains: ["屏幕取词", "本地识别"]
        )
    }

    func testLowResolutionEmptyFirstPassUsesRetryAndRecoversText() {
        let result = OCRService().recognizeText(
            in: image(
                size: NSSize(width: 160, height: 34),
                blocks: [block("LOCAL OCR 2026", x: 8, y: 11, width: 145, height: 12, size: 4.5)]
            ),
            recognitionLanguages: languages
        )

        XCTAssertTrue(result.didRetry, "Expected low-resolution fixture to enter the guarded retry path")
        XCTAssertTrue(normalize(result.text).contains("local"), "Unexpected OCR output: \(result.text)")
    }

    func testTraditionalChineseOnDarkBackground() {
        assertRecognizes(
            fixture: image(
                background: .black,
                blocks: [block("螢幕取詞使用本機辨識，深色背景保持可讀。", x: 30, y: 72, width: 760, height: 44, size: 23, color: .white)]
            ),
            contains: ["螢幕取詞", "本機辨識"]
        )
    }

    func testJapaneseWithDifferentFontSizes() {
        assertRecognizes(
            fixture: image(blocks: [
                block("画面の文字", x: 35, y: 105, width: 270, height: 58, size: 34),
                block("をローカルで認識します。", x: 310, y: 112, width: 470, height: 44, size: 20)
            ]),
            contains: ["画面の文字", "ローカル"]
        )
    }

    func testKoreanParagraph() {
        assertRecognizes(
            fixture: image(blocks: [
                block("화면의 글자를 로컬에서 인식합니다.", x: 35, y: 92, width: 740, height: 48, size: 25),
                block("원문은 자동으로 복사됩니다.", x: 35, y: 45, width: 740, height: 42, size: 21)
            ]),
            contains: ["화면의글자", "로컬"]
        )
    }

    func testMixedLanguageText() {
        assertRecognizes(
            fixture: image(blocks: [
                block("使用 ScreenTextClip 进行 local OCR，然后翻译结果。", x: 30, y: 80, width: 760, height: 50, size: 23)
            ]),
            contains: ["screentextclip", "localocr", "翻译"]
        )
    }

    func testObviousTwoColumnFixtureKeepsColumnOrder() {
        let result = OCRService().recognizeText(
            in: image(blocks: [
                block("Alpha one", x: 35, y: 125, width: 300, height: 40, size: 22),
                block("Alpha two", x: 35, y: 75, width: 300, height: 40, size: 22),
                block("Beta one", x: 460, y: 125, width: 300, height: 40, size: 22),
                block("Beta two", x: 460, y: 75, width: 300, height: 40, size: 22)
            ]),
            recognitionLanguages: languages
        )

        let normalized = normalize(result.text)
        guard
            let alphaTwo = normalized.range(of: "alphatwo")?.lowerBound,
            let betaOne = normalized.range(of: "betaone")?.lowerBound
        else {
            return XCTFail("Expected both columns in OCR output: \(result.text)")
        }
        XCTAssertLessThan(alphaTwo, betaOne, "Expected left column before right column: \(result.text)")
    }

    @discardableResult
    private func assertRecognizes(
        fixture: NSImage,
        contains expectedFragments: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> OCRRecognitionResult {
        let result = OCRService().recognizeText(in: fixture, recognitionLanguages: languages)
        let normalized = normalize(result.text)

        for fragment in expectedFragments {
            XCTAssertTrue(
                normalized.contains(normalize(fragment)),
                "Missing '\(fragment)' in OCR output: \(result.text)",
                file: file,
                line: line
            )
        }
        return result
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private func image(
        size: NSSize = NSSize(width: 820, height: 190),
        background: NSColor = .white,
        blocks: [FixtureTextBlock]
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        background.setFill()
        NSRect(origin: .zero, size: size).fill()

        for block in blocks {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byClipping
            (block.text as NSString).draw(
                with: block.rect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: NSFont.systemFont(ofSize: block.fontSize),
                    .foregroundColor: block.color,
                    .paragraphStyle: paragraph
                ]
            )
        }

        image.unlockFocus()
        return image
    }

    private func block(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        size: CGFloat,
        color: NSColor = .black
    ) -> FixtureTextBlock {
        FixtureTextBlock(
            text: text,
            rect: CGRect(x: x, y: y, width: width, height: height),
            fontSize: size,
            color: color
        )
    }
}

private struct FixtureTextBlock {
    let text: String
    let rect: CGRect
    let fontSize: CGFloat
    let color: NSColor
}

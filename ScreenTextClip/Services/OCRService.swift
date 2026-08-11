import AppKit
import Vision

struct OCRRecognitionResult {
    let text: String
    let confidence: Float
    let didRetry: Bool
}

struct OCRTextItem {
    let text: String
    let box: CGRect
    let confidence: Float
}

final class OCRService {
    private let retryConfidenceThreshold: Float = 0.45
    private let lowResolutionConfidenceThreshold: Float = 0.51

    func recognizeText(in image: NSImage, recognitionLanguages: [String]) -> OCRRecognitionResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return OCRRecognitionResult(text: "", confidence: 0, didRetry: false)
        }

        let first = performRecognition(in: cgImage, recognitionLanguages: recognitionLanguages)
        let isLowResolution = min(cgImage.width, cgImage.height) < 96
        let shouldRetry = first.text.isEmpty
            || first.confidence < retryConfidenceThreshold
            || (isLowResolution && first.confidence < lowResolutionConfidenceThreshold)
        guard shouldRetry else {
            DebugLogger.log(
                "first pass accepted confidence=\(format(first.confidence)) characters=\(first.text.count)",
                category: "OCR"
            )
            return OCRRecognitionResult(text: first.text, confidence: first.confidence, didRetry: false)
        }

        let retryImage = upscaledImage(from: cgImage) ?? cgImage
        DebugLogger.log(
            "retry triggered reason=\(first.text.isEmpty ? "empty" : "low-confidence") confidence=\(format(first.confidence)) input=\(cgImage.width)x\(cgImage.height) retry=\(retryImage.width)x\(retryImage.height)",
            category: "OCR"
        )
        let second = performRecognition(in: retryImage, recognitionLanguages: recognitionLanguages)
        let selected = preferredResult(first: first, second: second)

        DebugLogger.log(
            "retry finished first=\(format(first.confidence))/\(first.text.count) second=\(format(second.confidence))/\(second.text.count) selected=\(selected === first ? "first" : "second")",
            category: "OCR"
        )
        return OCRRecognitionResult(text: selected.text, confidence: selected.confidence, didRetry: true)
    }

    private func performRecognition(in cgImage: CGImage, recognitionLanguages: [String]) -> OCRPassResult {
        var items: [OCRTextItem] = []

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                items = []
                return
            }

            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            items = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first, !candidate.string.isEmpty else {
                    return nil
                }
                return OCRTextItem(
                    text: candidate.string,
                    box: observation.boundingBox,
                    confidence: candidate.confidence
                )
            }
        }
        request.revision = VNRecognizeTextRequest.currentRevision
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = recognitionLanguages
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return OCRPassResult(text: "", confidence: 0)
        }

        return OCRPassResult(
            text: OCRTextLayout.orderedText(from: items),
            confidence: weightedConfidence(of: items)
        )
    }

    private func weightedConfidence(of items: [OCRTextItem]) -> Float {
        let weighted = items.reduce(into: (sum: Float(0), weight: Float(0))) { result, item in
            let weight = Float(max(1, item.text.count))
            result.sum += item.confidence * weight
            result.weight += weight
        }
        return weighted.weight > 0 ? weighted.sum / weighted.weight : 0
    }

    private func preferredResult(first: OCRPassResult, second: OCRPassResult) -> OCRPassResult {
        if first.text.isEmpty { return second }
        if second.text.isEmpty { return first }
        if second.confidence >= first.confidence + 0.03 { return second }
        if second.text.count > first.text.count && second.confidence >= first.confidence - 0.08 { return second }
        return first
    }

    private func upscaledImage(from image: CGImage) -> CGImage? {
        let longestSide = max(image.width, image.height)
        guard longestSide > 0 else { return nil }

        let scale = min(2.0, 4096.0 / CGFloat(longestSide))
        guard scale > 1.05 else { return nil }

        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func format(_ confidence: Float) -> String {
        String(format: "%.3f", confidence)
    }
}

private final class OCRPassResult {
    let text: String
    let confidence: Float

    init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

enum OCRTextLayout {
    static func orderedText(from items: [OCRTextItem]) -> String {
        guard !items.isEmpty else { return "" }

        return detectedColumns(in: items)
            .map(textForColumn)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func detectedColumns(in items: [OCRTextItem]) -> [[OCRTextItem]] {
        guard items.count >= 4 else { return [items] }

        let sortedByCenter = items.sorted { $0.box.midX < $1.box.midX }
        let gaps = zip(sortedByCenter, sortedByCenter.dropFirst()).map { lhs, rhs in
            (gap: rhs.box.midX - lhs.box.midX, lhs: lhs, rhs: rhs)
        }
        guard let largest = gaps.max(by: { $0.gap < $1.gap }) else { return [items] }

        let medianHeight = median(items.map(\.box.height))
        guard largest.gap >= max(0.16, medianHeight * 3.0) else { return [items] }

        let split = (largest.lhs.box.midX + largest.rhs.box.midX) / 2
        let left = items.filter { $0.box.maxX < split }
        let right = items.filter { $0.box.minX > split }
        let crossing = items.filter { $0.box.minX <= split && $0.box.maxX >= split }

        guard left.count >= 2, right.count >= 2, crossing.isEmpty else { return [items] }

        let horizontalGap = (right.map(\.box.minX).min() ?? split) - (left.map(\.box.maxX).max() ?? split)
        guard horizontalGap >= max(0.04, medianHeight) else { return [items] }

        let leftY = verticalRange(of: left)
        let rightY = verticalRange(of: right)
        let overlap = leftY.intersection(rightY).length / max(0.001, min(leftY.length, rightY.length))
        guard overlap >= 0.35 else { return [items] }

        return [left, right]
    }

    private static func textForColumn(_ items: [OCRTextItem]) -> String {
        var lines: [OCRLine] = []
        let visuallySorted = items.sorted {
            if abs($0.box.midY - $1.box.midY) > 0.01 {
                return $0.box.midY > $1.box.midY
            }
            return $0.box.minX < $1.box.minX
        }

        for item in visuallySorted {
            if let index = lines.indices.min(by: {
                lines[$0].verticalDistance(to: item) < lines[$1].verticalDistance(to: item)
            }), lines[index].accepts(item) {
                lines[index].append(item)
            } else {
                lines.append(OCRLine(item: item))
            }
        }

        return lines
            .sorted { $0.midY > $1.midY }
            .map { line in
                line.items
                    .sorted { $0.box.minX < $1.box.minX }
                    .map(\.text)
                    .reduce("") { joinedText($0, $1) }
            }
            .joined(separator: "\n")
    }

    private static func joinedText(_ lhs: String, _ rhs: String) -> String {
        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }

        let left = lhs.trimmingCharacters(in: .whitespaces)
        let right = rhs.trimmingCharacters(in: .whitespaces)
        guard let leftScalar = left.unicodeScalars.last, let rightScalar = right.unicodeScalars.first else {
            return left + right
        }

        if (isCJK(leftScalar) || isCJKPunctuation(leftScalar)) && isCJK(rightScalar) {
            return left + right
        }
        if isCJK(leftScalar) && isOpeningPunctuation(rightScalar) {
            return left + right
        }
        if isClosingPunctuation(rightScalar) || isOpeningPunctuation(leftScalar) {
            return left + right
        }
        return left + " " + right
    }

    private static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x30FF, 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
             0x1100...0x11FF, 0x3130...0x318F, 0xAC00...0xD7AF, 0xFF66...0xFF9D,
             0x20000...0x2FA1F:
            return true
        default:
            return false
        }
    }

    private static func isClosingPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet(charactersIn: ",.!?:;%)]}，。！？：；、）》】」』〉］）").contains(scalar)
    }

    private static func isOpeningPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet(charactersIn: "([{（《【「『〈［").contains(scalar)
    }

    private static func isCJKPunctuation(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet(charactersIn: "，。！？：；、）》】」』〉］）").contains(scalar)
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func verticalRange(of items: [OCRTextItem]) -> ClosedRange<CGFloat> {
        let minimum = items.map(\.box.minY).min() ?? 0
        let maximum = items.map(\.box.maxY).max() ?? 0
        return minimum...maximum
    }
}

private struct OCRLine {
    private(set) var items: [OCRTextItem]
    private(set) var bounds: CGRect

    init(item: OCRTextItem) {
        items = [item]
        bounds = item.box
    }

    var midY: CGFloat { bounds.midY }

    func verticalDistance(to item: OCRTextItem) -> CGFloat {
        abs(item.box.midY - midY)
    }

    func accepts(_ item: OCRTextItem) -> Bool {
        let overlap = max(0, min(bounds.maxY, item.box.maxY) - max(bounds.minY, item.box.minY))
        let overlapRatio = overlap / max(0.001, min(bounds.height, item.box.height))
        let dynamicMidpointTolerance = max(0.012, max(bounds.height, item.box.height) * 0.32)
        return overlapRatio >= 0.40 || verticalDistance(to: item) <= dynamicMidpointTolerance
    }

    mutating func append(_ item: OCRTextItem) {
        items.append(item)
        bounds = bounds.union(item.box)
    }
}

private extension ClosedRange where Bound == CGFloat {
    var length: CGFloat { Swift.max(0, upperBound - lowerBound) }

    func intersection(_ other: ClosedRange<CGFloat>) -> ClosedRange<CGFloat> {
        let lower = Swift.max(lowerBound, other.lowerBound)
        let upper = Swift.max(lower, Swift.min(upperBound, other.upperBound))
        return lower...upper
    }
}

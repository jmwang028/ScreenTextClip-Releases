import AppKit
import ScreenCaptureKit

final class ScreenCaptureService {
    func capture(_ selection: SelectionResult, completion: @escaping (NSImage?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
                    debugLog(selection: selection, display: nil, sourceRect: .zero, pixelWidth: 0, pixelHeight: 0)
                    await MainActor.run { completion(nil) }
                    return
                }

                let sourceRect = makeSourceRect(from: selection)
                let scale = selection.screen.backingScaleFactor
                let pixelWidth = max(1, Int((sourceRect.width * scale).rounded()))
                let pixelHeight = max(1, Int((sourceRect.height * scale).rounded()))

                debugLog(selection: selection, display: display, sourceRect: sourceRect, pixelWidth: pixelWidth, pixelHeight: pixelHeight)

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = sourceRect
                config.width = pixelWidth
                config.height = pixelHeight
                config.showsCursor = false

                let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                let image = NSImage(cgImage: cgImage, size: NSSize(width: sourceRect.width, height: sourceRect.height))

                await MainActor.run {
                    completion(image)
                }
            } catch {
                DebugLogger.log("ScreenCaptureKit failed: \(error.localizedDescription)", category: "ScreenCaptureService")
                await MainActor.run {
                    completion(nil)
                }
            }
        }
    }

    private func makeSourceRect(from selection: SelectionResult) -> CGRect {
        let local = selection.screenLocalRect.standardized
        let screenHeight = selection.screen.frame.height

        return CGRect(
            x: local.minX,
            y: screenHeight - local.maxY,
            width: local.width,
            height: local.height
        )
    }

    private func debugLog(selection: SelectionResult, display: SCDisplay?, sourceRect: CGRect, pixelWidth: Int, pixelHeight: Int) {
        DebugLogger.log("""
        CaptureCoordinates
          selected NSScreen.frame: \(selection.screen.frame)
          selected NSScreen.backingScaleFactor: \(selection.screen.backingScaleFactor)
          matched CGDirectDisplayID: \(selection.displayID)
          matched SCDisplay: \(display.map { "id=\($0.displayID), frame=\($0.frame), width=\($0.width), height=\($0.height)" } ?? "nil")
          selection rect in overlay window coordinates: \(selection.windowRect)
          selection rect in NSScreen local point coordinates: \(selection.screenLocalRect)
          final SCStreamConfiguration.sourceRect: \(sourceRect)
          final config.width / config.height: \(pixelWidth) / \(pixelHeight)
        """, category: "ScreenCaptureService")
    }
}

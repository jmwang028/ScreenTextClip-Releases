import AppKit

final class SelectionOverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let displayID: CGDirectDisplayID

    var onSelectionComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private let overlayView = SelectionOverlayView()
    private var startPoint: CGPoint?
    private var currentRect: CGRect = .zero

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen) {
        self.targetScreen = screen
        self.displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
            .flatMap { ($0 as? NSNumber)?.uint32Value } ?? 0

        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)

        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        contentView = overlayView
    }

    func showOverlay() {
        orderFrontRegardless()
    }

    func screenLocalRect(fromWindowRect rect: CGRect) -> CGRect {
        let bounds = overlayView.bounds
        return rect.standardized.intersection(bounds)
    }

    override func mouseDown(with event: NSEvent) {
        makeKeyAndOrderFront(nil)
        let point = clamped(event.locationInWindow)
        startPoint = point
        currentRect = .zero
        overlayView.selectionRect = .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint else { return }
        let currentPoint = clamped(event.locationInWindow)
        currentRect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
        overlayView.selectionRect = currentRect
    }

    override func mouseUp(with event: NSEvent) {
        guard currentRect.width >= 4, currentRect.height >= 4 else {
            onCancel?()
            return
        }
        onSelectionComplete?(currentRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        overlayView.addCursorRect(overlayView.bounds, cursor: .crosshair)
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        let bounds = overlayView.bounds
        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}

final class SelectionOverlayView: NSView {
    var selectionRect: CGRect = .zero {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        guard selectionRect.width > 0, selectionRect.height > 0 else { return }

        NSColor.white.withAlphaComponent(0.24).setFill()
        selectionRect.fill()

        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2
        path.stroke()
    }
}

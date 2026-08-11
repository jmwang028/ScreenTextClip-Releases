import AppKit

struct SelectionResult {
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    let windowRect: CGRect
    let screenLocalRect: CGRect
}

final class MultiDisplaySelectionOverlay {
    private var windows: [SelectionOverlayWindow] = []
    private var completion: ((SelectionResult?) -> Void)?
    private var keyMonitor: Any?
    private var hasFinished = false

    func beginSelection(completion: @escaping (SelectionResult?) -> Void) {
        finish(nil)

        self.completion = completion
        hasFinished = false

        NSApp.activate()

        windows = NSScreen.screens.map { screen in
            let window = SelectionOverlayWindow(screen: screen)
            window.onSelectionComplete = { [weak self, weak window] rect in
                guard let self, let window else { return }
                self.completeSelection(from: window, windowRect: rect)
            }
            window.onCancel = { [weak self] in
                self?.finish(nil)
            }
            return window
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.finish(nil)
                return nil
            }
            return event
        }

        windows.forEach { $0.showOverlay() }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private func completeSelection(from window: SelectionOverlayWindow, windowRect: CGRect) {
        guard !hasFinished else { return }

        let screenLocalRect = window.screenLocalRect(fromWindowRect: windowRect)
        let result = SelectionResult(
            screen: window.targetScreen,
            displayID: window.displayID,
            windowRect: windowRect,
            screenLocalRect: screenLocalRect
        )

        finish(result)
    }

    private func finish(_ result: SelectionResult?) {
        guard completion != nil || !windows.isEmpty || keyMonitor != nil else { return }

        hasFinished = true

        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }

        let callback = completion
        completion = nil

        windows.forEach { $0.close() }
        windows.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            callback?(result)
        }
    }
}

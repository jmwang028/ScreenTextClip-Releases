import AppKit

@main
enum ScreenTextClipMain {
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        appDelegate = delegate
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBarController = MenuBarController()
    private lazy var hotkeyManager = HotkeyManager { [weak self] in
        self?.menuBarController.captureText()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DebugLogger.log("applicationDidFinishLaunching", category: "AppDelegate")
        NSApp.setActivationPolicy(.accessory)
        menuBarController.setup()
        hotkeyManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }
}

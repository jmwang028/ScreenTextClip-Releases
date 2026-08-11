import AppKit
import ServiceManagement

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let languageSettings = LanguageSettings()
    private let translationMenu = NSMenu(title: "Translate To")
    private let managementMenu = NSMenu(title: "Manage Languages")
    private let interfaceLanguageMenu = NSMenu(title: "Interface Language")
    private lazy var launchAtLoginMenuItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        item.target = self
        return item
    }()
    private lazy var captureCoordinator = CaptureCoordinator(
        languageSettings: languageSettings
    )
    private var isLoadingLanguages = true
    private var languageLoadingFailed = false

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = makeMenuBarIcon()
            button.imagePosition = .imageOnly
            button.title = ""
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("ScreenTextClip")
        }

        rebuildMenu()
        loadAvailableLanguages()
    }

    func captureText() {
        captureCoordinator.start()
    }

    private func rebuildMenu() {
        menu.removeAllItems()
        statusItem?.button?.toolTip = InterfaceText.localized(
            "Click to capture text. Right-click for menu.",
            "单击截取文字，右键打开菜单。"
        )

        let capture = NSMenuItem(
            title: InterfaceText.localized("Capture Text", "截取文字"),
            action: #selector(captureTextMenuItem),
            keyEquivalent: "s"
        )
        capture.keyEquivalentModifierMask = [.control, .command]
        capture.target = self
        menu.addItem(capture)

        translationMenu.title = InterfaceText.localized("Translate To", "翻译为")
        let translateTo = NSMenuItem(title: translationMenu.title, action: nil, keyEquivalent: "")
        translateTo.submenu = translationMenu
        if #unavailable(macOS 15.0) {
            translateTo.isEnabled = false
        }
        menu.addItem(translateTo)
        rebuildLanguageMenus()

        rebuildInterfaceLanguageMenu()
        let interfaceLanguage = NSMenuItem(
            title: InterfaceText.localized("Interface Language", "界面语言"),
            action: nil,
            keyEquivalent: ""
        )
        interfaceLanguage.submenu = interfaceLanguageMenu
        menu.addItem(interfaceLanguage)

        menu.addItem(.separator())
        launchAtLoginMenuItem.title = InterfaceText.localized("Launch at Login", "登录时启动")
        menu.addItem(launchAtLoginMenuItem)
        updateLaunchAtLoginMenuItem()

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: InterfaceText.localized("Quit", "退出"),
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    private func rebuildInterfaceLanguageMenu() {
        interfaceLanguageMenu.removeAllItems()

        for language in InterfaceLanguage.allCases {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(selectInterfaceLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = language == InterfaceText.language ? .on : .off
            interfaceLanguageMenu.addItem(item)
        }
    }

    private func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let brackets = NSBezierPath()
            brackets.lineWidth = 1.6
            brackets.lineCapStyle = .round
            brackets.lineJoinStyle = .round
            brackets.move(to: NSPoint(x: 7, y: 15.5))
            brackets.line(to: NSPoint(x: 5.5, y: 15.5))
            brackets.curve(
                to: NSPoint(x: 2.5, y: 12.5),
                controlPoint1: NSPoint(x: 3.7, y: 15.5),
                controlPoint2: NSPoint(x: 2.5, y: 14.3)
            )
            brackets.line(to: NSPoint(x: 2.5, y: 5.5))
            brackets.curve(
                to: NSPoint(x: 5.5, y: 2.5),
                controlPoint1: NSPoint(x: 2.5, y: 3.7),
                controlPoint2: NSPoint(x: 3.7, y: 2.5)
            )
            brackets.line(to: NSPoint(x: 7, y: 2.5))

            brackets.move(to: NSPoint(x: 13, y: 15.5))
            brackets.line(to: NSPoint(x: 14.5, y: 15.5))
            brackets.curve(
                to: NSPoint(x: 17.5, y: 12.5),
                controlPoint1: NSPoint(x: 16.3, y: 15.5),
                controlPoint2: NSPoint(x: 17.5, y: 14.3)
            )
            brackets.line(to: NSPoint(x: 17.5, y: 5.5))
            brackets.curve(
                to: NSPoint(x: 14.5, y: 2.5),
                controlPoint1: NSPoint(x: 17.5, y: 3.7),
                controlPoint2: NSPoint(x: 16.3, y: 2.5)
            )
            brackets.line(to: NSPoint(x: 13, y: 2.5))
            brackets.stroke()

            let textLines = NSBezierPath()
            textLines.lineWidth = 1.4
            textLines.lineCapStyle = .round
            textLines.move(to: NSPoint(x: 6.5, y: 11.5))
            textLines.line(to: NSPoint(x: 13.5, y: 11.5))
            textLines.move(to: NSPoint(x: 6.5, y: 8.7))
            textLines.line(to: NSPoint(x: 13.5, y: 8.7))
            textLines.move(to: NSPoint(x: 7.5, y: 5.9))
            textLines.line(to: NSPoint(x: 12.5, y: 5.9))
            textLines.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func captureTextMenuItem() {
        captureText()
    }

    @objc private func selectInterfaceLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = InterfaceLanguage(rawValue: rawValue)
        else {
            return
        }

        InterfaceText.language = language
        rebuildMenu()
    }

    @objc private func selectTranslationLanguage(_ sender: NSMenuItem) {
        guard let languageID = sender.representedObject as? String else { return }
        languageSettings.setTargetLanguage(id: languageID)
        rebuildLanguageMenus()
    }

    @objc private func toggleLanguage(_ sender: NSMenuItem) {
        guard let languageID = sender.representedObject as? String else { return }
        let shouldEnable = !languageSettings.isLanguageEnabled(id: languageID)
        languageSettings.setLanguage(
            id: languageID,
            enabled: shouldEnable
        )
        if shouldEnable {
            languageSettings.setTargetLanguage(id: languageID)
        }
        rebuildLanguageMenus()
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
            return
        }

        captureText()
    }

    private func showMenu() {
        guard let item = statusItem else { return }

        updateLaunchAtLoginMenuItem()
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                showLoginItemsGuidance()
                return
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }

            updateLaunchAtLoginMenuItem()
            if service.status == .requiresApproval {
                showLoginItemsGuidance()
            }
        } catch {
            updateLaunchAtLoginMenuItem()
            showLaunchAtLoginError(error)
        }
    }

    private func updateLaunchAtLoginMenuItem() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLoginMenuItem.state = .on
        case .requiresApproval:
            launchAtLoginMenuItem.state = .mixed
        case .notRegistered, .notFound:
            launchAtLoginMenuItem.state = .off
        @unknown default:
            launchAtLoginMenuItem.state = .off
        }
    }

    private func showLoginItemsGuidance() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = InterfaceText.localized(
            "Allow ScreenTextClip at Login",
            "允许 ScreenTextClip 登录时启动"
        )
        alert.informativeText = InterfaceText.localized(
            "In System Settings > General > Login Items, allow ScreenTextClip to open at login.",
            "请在“系统设置 > 通用 > 登录项”中允许 ScreenTextClip 登录时打开。"
        )
        alert.addButton(withTitle: InterfaceText.localized("Open Login Items", "打开登录项"))
        alert.addButton(withTitle: InterfaceText.localized("Not Now", "暂不"))

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func showLaunchAtLoginError(_ error: Error) {
        DebugLogger.log(
            "launch at login update failed error=\(error.localizedDescription)",
            category: "LaunchAtLogin"
        )
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = InterfaceText.localized(
            "Could Not Change Login Setting",
            "无法更改登录启动设置"
        )
        alert.informativeText = InterfaceText.localized(
            "Open System Settings > General > Login Items and change ScreenTextClip manually.",
            "请打开“系统设置 > 通用 > 登录项”，手动更改 ScreenTextClip 设置。"
        )
        alert.addButton(withTitle: InterfaceText.localized("Open Login Items", "打开登录项"))
        alert.addButton(withTitle: InterfaceText.localized("OK", "好"))

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func loadAvailableLanguages() {
        guard #available(macOS 15.0, *) else { return }

        languageSettings.loadAvailableLanguages { [weak self] result in
            guard let self else { return }
            self.isLoadingLanguages = false
            switch result {
            case .success:
                let mappings = self.languageSettings.availableLanguages
                    .map { "\($0.displayName):\($0.ocrIdentifier)->\($0.translationIdentifier)" }
                    .joined(separator: ",")
                DebugLogger.log("language catalog loaded mappings=\(mappings)", category: "Languages")
            case .failure(let error):
                self.languageLoadingFailed = true
                DebugLogger.log("language catalog failed error=\(error.localizedDescription)", category: "Languages")
            }
            self.rebuildLanguageMenus()
        }
    }

    private func rebuildLanguageMenus() {
        translationMenu.removeAllItems()

        for language in languageSettings.enabledLanguages {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(selectTranslationLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.id
            item.state = language.id == languageSettings.targetLanguage.id ? .on : .off
            translationMenu.addItem(item)
        }

        translationMenu.addItem(.separator())
        rebuildManagementMenu()
        managementMenu.title = InterfaceText.localized("Manage Languages", "管理语言")
        let manageLanguages = NSMenuItem(
            title: InterfaceText.localized("Manage Languages…", "管理语言…"),
            action: nil,
            keyEquivalent: ""
        )
        manageLanguages.submenu = managementMenu
        translationMenu.addItem(manageLanguages)
    }

    private func rebuildManagementMenu() {
        managementMenu.removeAllItems()

        for language in languageSettings.availableLanguages {
            let item = NSMenuItem(
                title: language.displayName,
                action: #selector(toggleLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.id
            item.state = languageSettings.isLanguageEnabled(id: language.id) ? .on : .off
            item.isEnabled = !language.isBuiltIn
            managementMenu.addItem(item)
        }

        if isLoadingLanguages || languageLoadingFailed {
            managementMenu.addItem(.separator())
            let statusTitle = isLoadingLanguages
                ? InterfaceText.localized("Loading Languages…", "正在加载语言…")
                : InterfaceText.localized("Languages Unavailable", "语言不可用")
            managementMenu.addItem(NSMenuItem(title: statusTitle, action: nil, keyEquivalent: ""))
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

import AppKit

enum NotificationService {
    private static var activePanels: [NSPanel] = []

    static func showPermissionGuidance() {
        show(
            InterfaceText.localized(
                """
                Screen Recording permission is required.
                System Settings > Privacy & Security > Screen Recording
                Quit and relaunch after granting permission if capture still fails.
                """,
                """
                需要屏幕录制权限。
                系统设置 > 隐私与安全性 > 屏幕录制
                授权后如果仍无法截取，请退出并重新打开应用。
                """
            ),
            duration: 4
        )
    }

    static func show(_ message: String, duration: TimeInterval = 2) {
        DispatchQueue.main.async {
            let panel = makePanel(message: message)
            activePanels.append(panel)
            panel.alphaValue = 0
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.2
                    panel.animator().alphaValue = 0
                }, completionHandler: {
                    panel.orderOut(nil)
                    activePanels.removeAll { $0 === panel }
                })
            }
        }
    }

    private static func makePanel(message: String) -> NSPanel {
        let width: CGFloat = 420
        let height: CGFloat = message.contains("\n") ? 112 : 52
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let rect = CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - height - 28,
            width: width,
            height: height
        )

        let panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true

        let container = NSView(frame: CGRect(origin: .zero, size: rect.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor
        container.layer?.cornerRadius = 8

        let label = NSTextField(labelWithString: message)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 4
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        panel.contentView = container
        return panel
    }
}

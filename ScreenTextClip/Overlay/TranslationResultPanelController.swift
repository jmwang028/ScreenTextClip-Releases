import AppKit

final class TranslationResultPanelController: NSObject {
    var onClose: (() -> Void)?

    private var panel: TranslationPanel?
    private var statusImage: NSImageView?
    private var titleLabel: NSTextField?
    private var scrollView: NSScrollView?
    private var textView: NSTextView?
    private var anchor: PanelAnchor?
    private var escapeMonitor: Any?

    func showLoading(
        targetLanguage: AppLanguage,
        selection: SelectionResult
    ) -> NSView {
        dismissPanel(notify: false)

        anchor = PanelAnchor(selection: selection)
        let interface = makePanel(targetLanguage: targetLanguage)
        panel = interface.panel
        statusImage = interface.statusImage
        titleLabel = interface.titleLabel
        scrollView = interface.scrollView
        textView = interface.textView

        interface.statusImage.contentTintColor = .tertiaryLabelColor
        let translating = InterfaceText.localized("Translating…", "正在翻译…")
        interface.statusImage.setAccessibilityLabel(
            InterfaceText.localized("Translating", "正在翻译")
        )
        updateText(translating, color: .secondaryLabelColor)
        resizePanel(for: translating)
        installEscapeMonitor()
        interface.panel.orderFrontRegardless()
        return interface.bridgeContainer
    }

    func showTranslation(_ text: String) {
        statusImage?.contentTintColor = .systemGreen
        statusImage?.setAccessibilityLabel(
            InterfaceText.localized("Translation complete", "翻译完成")
        )
        updateText(text, color: .labelColor)
        resizePanel(for: text)
    }

    func showError(_ message: String) {
        statusImage?.contentTintColor = .systemOrange
        let unavailable = InterfaceText.localized("Translation unavailable", "翻译不可用")
        statusImage?.setAccessibilityLabel(unavailable)
        titleLabel?.stringValue = unavailable
        updateText(message, color: .secondaryLabelColor)
        resizePanel(for: message)
    }

    @objc func close() {
        dismissPanel(notify: true)
    }

    private func dismissPanel(notify: Bool) {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }

        let hadPanel = panel != nil
        panel?.orderOut(nil)
        panel = nil
        statusImage = nil
        titleLabel = nil
        scrollView = nil
        textView = nil
        anchor = nil

        if notify && hadPanel {
            onClose?()
        }
    }

    private func makePanel(targetLanguage: AppLanguage) -> PanelInterface {
        let initialRect = CGRect(x: 0, y: 0, width: 300, height: 112)
        let panel = TranslationPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let glass = RoundedVisualEffectView(cornerRadius: 14)
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 14
        glass.layer?.cornerCurve = .continuous
        glass.layer?.masksToBounds = true
        glass.layer?.borderWidth = 1
        glass.layer?.borderColor = NSColor.white.withAlphaComponent(0.42).cgColor

        let header = DraggableHeaderView()
        header.translatesAutoresizingMaskIntoConstraints = false

        let statusImage = NSImageView()
        statusImage.translatesAutoresizingMaskIntoConstraints = false
        statusImage.image = NSImage(
            systemSymbolName: "circle.fill",
            accessibilityDescription: InterfaceText.localized("Translating", "正在翻译")
        )
        statusImage.contentTintColor = .tertiaryLabelColor
        statusImage.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 7, weight: .medium)

        let titleLabel = NSTextField(labelWithString: InterfaceText.localized(
            "Translation · \(targetLanguage.displayName)",
            "翻译为 \(targetLanguage.displayName)"
        ))
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isBordered = false
        let closeLabel = InterfaceText.localized("Close", "关闭")
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: closeLabel)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        closeButton.toolTip = closeLabel
        closeButton.target = self
        closeButton.action = #selector(close)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = NSTextView(frame: CGRect(x: 0, y: 0, width: 300, height: 1))
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 16, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: 300,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        let bridgeContainer = NSView()
        bridgeContainer.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(statusImage)
        header.addSubview(titleLabel)
        header.addSubview(closeButton)
        glass.addSubview(header)
        glass.addSubview(separator)
        glass.addSubview(scrollView)
        glass.addSubview(bridgeContainer)
        panel.contentView = glass

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: glass.topAnchor),
            header.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 48),

            statusImage.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            statusImage.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            statusImage.widthAnchor.constraint(equalToConstant: 8),
            statusImage.heightAnchor.constraint(equalToConstant: 8),

            titleLabel.leadingAnchor.constraint(equalTo: statusImage.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -10),

            closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -11),
            closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 26),
            closeButton.heightAnchor.constraint(equalToConstant: 26),

            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: glass.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: glass.bottomAnchor),

            bridgeContainer.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            bridgeContainer.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            bridgeContainer.widthAnchor.constraint(equalToConstant: 1),
            bridgeContainer.heightAnchor.constraint(equalToConstant: 1)
        ])

        return PanelInterface(
            panel: panel,
            statusImage: statusImage,
            titleLabel: titleLabel,
            scrollView: scrollView,
            textView: textView,
            bridgeContainer: bridgeContainer
        )
    }

    private func updateText(_ text: String, color: NSColor) {
        guard let textView else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.lineBreakMode = .byWordWrapping

        textView.textStorage?.setAttributedString(NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ]
        ))
        textView.scrollToBeginningOfDocument(nil)
    }

    private func resizePanel(for text: String) {
        guard let panel, let anchor else { return }

        let visibleFrame = anchor.screen.visibleFrame
        let preferredWidth: CGFloat
        switch text.count {
        case 0..<80:
            preferredWidth = 320
        case 80..<220:
            preferredWidth = 380
        default:
            preferredWidth = 420
        }

        let width = min(preferredWidth, max(260, visibleFrame.width - 24))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.lineBreakMode = .byWordWrapping

        let bodyWidth = max(1, width - 32)
        let textBounds = (text as NSString).boundingRect(
            with: CGSize(width: bodyWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .paragraphStyle: paragraphStyle
            ]
        )

        let desiredHeight = 48 + ceil(textBounds.height) + 28
        let maximumHeight = min(400, floor(visibleFrame.height * 0.45))
        let height = min(maximumHeight, max(108, desiredHeight))
        panel.setFrame(positionedFrame(width: width, height: height, anchor: anchor), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.invalidateShadow()
        updateTextDocumentLayout()
    }

    private func updateTextDocumentLayout() {
        guard let scrollView, let textView, let textContainer = textView.textContainer else { return }

        let contentSize = scrollView.contentSize
        let textWidth = max(1, contentSize.width - textView.textContainerInset.width * 2)
        textView.setFrameSize(NSSize(width: contentSize.width, height: max(1, contentSize.height)))
        textContainer.containerSize = NSSize(
            width: textWidth,
            height: CGFloat.greatestFiniteMagnitude
        )

        if let layoutManager = textView.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
            let usedHeight = layoutManager.usedRect(for: textContainer).height
            let documentHeight = max(contentSize.height, usedHeight + textView.textContainerInset.height * 2)
            textView.setFrameSize(NSSize(width: contentSize.width, height: documentHeight))
        }
    }

    private func positionedFrame(width: CGFloat, height: CGFloat, anchor: PanelAnchor) -> CGRect {
        let visibleFrame = anchor.screen.visibleFrame
        let margin: CGFloat = 12
        let gap: CGFloat = 10

        let rightX = anchor.selectionRect.maxX + gap
        let leftX = anchor.selectionRect.minX - gap - width
        let x: CGFloat
        if rightX + width <= visibleFrame.maxX - margin {
            x = rightX
        } else if leftX >= visibleFrame.minX + margin {
            x = leftX
        } else {
            x = min(max(rightX, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        }

        let topAlignedY = anchor.selectionRect.maxY - height
        let y = min(
            max(topAlignedY, visibleFrame.minY + margin),
            visibleFrame.maxY - height - margin
        )
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.panel?.isVisible == true else { return event }
            self?.close()
            return nil
        }
    }
}

private final class TranslationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class RoundedVisualEffectView: NSVisualEffectView {
    private let maskCornerRadius: CGFloat
    private var maskedSize: NSSize = .zero

    init(cornerRadius: CGFloat) {
        self.maskCornerRadius = cornerRadius
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let size = bounds.size
        guard size.width > 0, size.height > 0, size != maskedSize else { return }
        maskedSize = size

        let radius = maskCornerRadius
        maskImage = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
    }
}

private final class DraggableHeaderView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hitView = super.hitTest(point)
        return hitView is NSButton ? hitView : self
    }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

private struct PanelAnchor {
    let screen: NSScreen
    let selectionRect: CGRect

    init(selection: SelectionResult) {
        screen = selection.screen
        selectionRect = CGRect(
            x: selection.screen.frame.minX + selection.screenLocalRect.minX,
            y: selection.screen.frame.minY + selection.screenLocalRect.minY,
            width: selection.screenLocalRect.width,
            height: selection.screenLocalRect.height
        )
    }
}

private struct PanelInterface {
    let panel: TranslationPanel
    let statusImage: NSImageView
    let titleLabel: NSTextField
    let scrollView: NSScrollView
    let textView: NSTextView
    let bridgeContainer: NSView
}

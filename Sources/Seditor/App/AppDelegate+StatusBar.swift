import AppKit
import CoreFoundation

@MainActor
extension AppDelegate {
    private var statusEncodingOptions: [(title: String, encoding: String.Encoding)] {
        [
            ("UTF-8", .utf8),
            ("GB18030", encodingFromCF(0x0632)),
            ("GBK", encodingFromCF(0x0631)),
            ("GB2312", encodingFromCF(0x0630))
        ]
    }

    func configureStatusBarView() {
        applyStatusBarPalette()
        statusBarView.layer?.borderWidth = 1
        statusBarView.layer?.zPosition = 90

        statusBarStack.orientation = .horizontal
        statusBarStack.alignment = .centerY
        statusBarStack.spacing = 10

        cursorPositionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        cursorPositionLabel.textColor = statusBarTextColor()
        cursorPositionLabel.setAccessibilityLabel(L10n.t("a11y.cursorPosition", "Cursor Position"))

        encodingPopup.target = self
        encodingPopup.action = #selector(changeStatusEncoding(_:))
        encodingPopup.font = NSFont.systemFont(ofSize: 12)
        encodingPopup.contentTintColor = statusBarTextColor()
        encodingPopup.setAccessibilityLabel(L10n.t("a11y.textEncoding", "Text Encoding"))
        encodingPopup.setAccessibilityHelp(L10n.t("a11y.textEncoding.help", "Changes encoding for the current document."))
        encodingPopup.toolTip = L10n.t("a11y.textEncoding.help", "Changes encoding for the current document.")

        lineEndingPopup.target = self
        lineEndingPopup.action = #selector(changeStatusLineEnding(_:))
        lineEndingPopup.font = NSFont.systemFont(ofSize: 12)
        lineEndingPopup.contentTintColor = statusBarTextColor()
        lineEndingPopup.setAccessibilityLabel(L10n.t("a11y.lineEndings", "Line Endings"))
        lineEndingPopup.setAccessibilityHelp(L10n.t("a11y.lineEndings.help", "Changes line endings for the current document."))
        lineEndingPopup.toolTip = L10n.t("a11y.lineEndings.help", "Changes line endings for the current document.")

        encodingPopup.removeAllItems()
        for (index, option) in statusEncodingOptions.enumerated() {
            encodingPopup.addItem(withTitle: option.title)
            encodingPopup.item(at: index)?.tag = index
        }

        lineEndingPopup.removeAllItems()
        lineEndingPopup.addItem(withTitle: "LF")
        lineEndingPopup.item(at: 0)?.representedObject = LineEndingStyle.lf.rawValue
        lineEndingPopup.addItem(withTitle: "CRLF")
        lineEndingPopup.item(at: 1)?.representedObject = LineEndingStyle.crlf.rawValue

        let spacer = NSView(frame: .zero)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusBarStack.addArrangedSubview(cursorPositionLabel)
        statusBarStack.addArrangedSubview(spacer)
        statusBarStack.addArrangedSubview(encodingPopup)
        statusBarStack.addArrangedSubview(lineEndingPopup)

        updateStatusBarForCurrentSession()
    }

    func updateStatusBarAppearance() {
        applyStatusBarPalette()
        cursorPositionLabel.textColor = statusBarTextColor()
        encodingPopup.contentTintColor = statusBarTextColor()
        lineEndingPopup.contentTintColor = statusBarTextColor()
    }

    func updateStatusBarForCurrentSession() {
        updateStatusBar(for: currentSession())
    }

    func updateStatusBar(for session: EditorSession?) {
        isUpdatingStatusBarControls = true
        defer { isUpdatingStatusBarControls = false }

        guard let session else {
            cursorPositionLabel.stringValue = L10n.t("status.cursor.none", "Ln -, Col -")
            encodingPopup.isEnabled = false
            lineEndingPopup.isEnabled = false
            if encodingPopup.numberOfItems > 0 {
                encodingPopup.selectItem(at: 0)
            }
            if lineEndingPopup.numberOfItems > 0 {
                lineEndingPopup.selectItem(at: 0)
            }
            return
        }

        encodingPopup.isEnabled = true
        lineEndingPopup.isEnabled = true

        updateCursorPositionLabel(for: session)

        if let index = statusEncodingOptions.firstIndex(where: { $0.encoding == session.currentFileEncoding }) {
            encodingPopup.selectItem(at: index)
        } else {
            encodingPopup.selectItem(at: 0)
        }

        let lineEndingTitle = session.preferredLineEnding == .crlf ? "CRLF" : "LF"
        lineEndingPopup.selectItem(withTitle: lineEndingTitle)
    }

    @objc func changeStatusEncoding(_ sender: NSPopUpButton) {
        guard !isUpdatingStatusBarControls else { return }
        guard let session = currentSession() else { return }
        guard let selected = sender.selectedItem else { return }

        let index = selected.tag
        guard statusEncodingOptions.indices.contains(index) else { return }
        let encoding = statusEncodingOptions[index].encoding

        guard session.currentFileEncoding != encoding else { return }
        session.currentFileEncoding = encoding

        if !session.hasPendingUnsavedChanges {
            session.hasPendingUnsavedChanges = true
            syncTabButtons()
        }
        persistWorkspaceState()
        updateStatusBar(for: session)
    }

    @objc func changeStatusLineEnding(_ sender: NSPopUpButton) {
        guard !isUpdatingStatusBarControls else { return }
        guard let session = currentSession() else { return }
        guard let raw = sender.selectedItem?.representedObject as? String,
              let style = LineEndingStyle(rawValue: raw)
        else { return }

        guard session.preferredLineEnding != style else { return }

        let original = session.textView.string
        let normalized = normalizeLineEndings(in: original, to: style)
        let oldRange = session.textView.selectedRange()

        session.preferredLineEnding = style

        if normalized != original {
            session.textView.undoManager?.disableUndoRegistration()
            session.textView.string = normalized
            session.textView.undoManager?.enableUndoRegistration()
            session.gutterView.invalidateCaches()
            let maxLocation = (normalized as NSString).length
            let location = min(oldRange.location, maxLocation)
            session.textView.setSelectedRange(NSRange(location: location, length: 0))
            requestRedraw(for: session, gutter: true, editor: true)
        }

        if !session.hasPendingUnsavedChanges {
            session.hasPendingUnsavedChanges = true
            syncTabButtons()
        }
        persistWorkspaceState()
        updateStatusBar(for: session)
    }

    func detectPreferredLineEnding(in text: String) -> LineEndingStyle {
        if text.contains("\r\n") {
            return .crlf
        }
        return .lf
    }

    func refreshPreferredLineEndingsForOpenFiles() {
        for session in workspaceController.allSessions() {
            session.preferredLineEnding = detectPreferredLineEnding(in: session.textView.string)
        }
        updateStatusBarForCurrentSession()
    }

    func textForSaving(from session: EditorSession) -> String {
        normalizeLineEndings(in: session.textView.string, to: session.preferredLineEnding)
    }

    private func normalizeLineEndings(in text: String, to style: LineEndingStyle) -> String {
        let lfNormalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        switch style {
        case .lf:
            return lfNormalized
        case .crlf:
            return lfNormalized.replacingOccurrences(of: "\n", with: "\r\n")
        }
    }

    private func updateCursorPositionLabel(for session: EditorSession) {
        let text = session.textView.string as NSString
        let location = min(session.textView.selectedRange().location, text.length)

        var line = 1
        var lineStart = 0
        while lineStart < location {
            let range = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let next = NSMaxRange(range)
            if next > location || next <= lineStart {
                break
            }
            line += 1
            lineStart = next
        }

        let column = max(1, location - lineStart + 1)
        cursorPositionLabel.stringValue = String(format: L10n.t("status.cursor", "Ln %d, Col %d"), line, column)
    }

    private func encodingFromCF(_ value: CFStringEncoding) -> String.Encoding {
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(value))
    }

    private func applyStatusBarPalette() {
        let (background, border) = statusBarColors()
        statusBarView.layer?.backgroundColor = background.cgColor
        statusBarView.layer?.borderColor = border.cgColor
    }

    private func statusBarTextColor() -> NSColor {
        switch editorTheme {
        case .dark:
            return NSColor(calibratedWhite: 0.90, alpha: 1)
        case .light:
            return NSColor(calibratedWhite: 0.12, alpha: 1)
        case .system:
            return .labelColor
        }
    }

    private func statusBarColors() -> (NSColor, NSColor) {
        switch editorTheme {
        case .dark:
            return (
                NSColor(calibratedWhite: 0.12, alpha: 1),
                NSColor(calibratedWhite: 0.26, alpha: 1)
            )
        case .light:
            return (
                NSColor(calibratedWhite: 0.97, alpha: 1),
                NSColor(calibratedWhite: 0.84, alpha: 1)
            )
        case .system:
            return (.windowBackgroundColor, .separatorColor)
        }
    }
}

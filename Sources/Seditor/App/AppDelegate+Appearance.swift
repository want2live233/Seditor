import AppKit

@MainActor
extension AppDelegate {
    func applyTheme() {
        for (_, session) in tabItemToSession {
            applyTheme(to: session)
        }
    }

    func applyTheme(to session: EditorSession) {
        let editorBackground: NSColor
        let editorForeground: NSColor
        let gutterBackground: NSColor
        let gutterForeground: NSColor
        let currentLineBackground: NSColor
        let currentLineNumberColor: NSColor
        let caretColor: NSColor

        switch editorTheme {
        case .system:
            editorBackground = .textBackgroundColor
            editorForeground = .textColor
            gutterBackground = .windowBackgroundColor
            gutterForeground = .secondaryLabelColor
            currentLineBackground = NSColor.controlAccentColor.withAlphaComponent(0.14)
            currentLineNumberColor = .labelColor
            caretColor = NSColor(calibratedRed: 0.29, green: 0.62, blue: 1.00, alpha: 1.0)
        case .light:
            editorBackground = NSColor(calibratedWhite: 0.98, alpha: 1)
            editorForeground = NSColor(calibratedWhite: 0.1, alpha: 1)
            gutterBackground = NSColor(calibratedWhite: 0.94, alpha: 1)
            gutterForeground = NSColor(calibratedWhite: 0.38, alpha: 1)
            currentLineBackground = NSColor(calibratedRed: 0.76, green: 0.85, blue: 1.0, alpha: 0.30)
            currentLineNumberColor = NSColor(calibratedWhite: 0.1, alpha: 1)
            caretColor = NSColor(calibratedRed: 0.05, green: 0.40, blue: 0.95, alpha: 1.0)
        case .dark:
            editorBackground = NSColor(calibratedWhite: 0.10, alpha: 1)
            editorForeground = NSColor(calibratedRed: 0.60, green: 0.63, blue: 0.68, alpha: 1)
            gutterBackground = NSColor(calibratedWhite: 0.14, alpha: 1)
            gutterForeground = NSColor(calibratedWhite: 0.55, alpha: 1)
            currentLineBackground = NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.80, alpha: 0.30)
            currentLineNumberColor = NSColor(calibratedWhite: 0.95, alpha: 1)
            caretColor = NSColor(calibratedRed: 0.42, green: 0.78, blue: 1.00, alpha: 1.0)
        }

        session.editorScrollView.drawsBackground = true
        session.editorScrollView.backgroundColor = editorBackground

        session.textView.drawsBackground = true
        session.textView.backgroundColor = editorBackground
        session.textView.textColor = editorForeground
        session.textView.insertionPointColor = caretColor
        session.textView.caretColor = caretColor
        session.textView.caretWidthScale = 1.6
        session.textView.caretHeightScale = 1.25
        session.textView.currentLineBackgroundColor = currentLineBackground

        var attrs = session.textView.typingAttributes
        attrs[.font] = NSFont.monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
        attrs[.foregroundColor] = editorForeground
        session.textView.typingAttributes = attrs

        session.gutterView.backgroundColor = gutterBackground
        session.gutterView.lineNumberColor = gutterForeground
        session.gutterView.highlightedLineBackgroundColor = currentLineBackground
        session.gutterView.highlightedLineNumberColor = currentLineNumberColor
        session.gutterView.lineNumberFont = .monospacedDigitSystemFont(ofSize: max(11, editorFontSize - 2), weight: .regular)
        session.gutterView.invalidateCaches()
        requestRedraw(for: session, gutter: true, editor: true)
    }

    func applyFontSize() {
        for (_, session) in tabItemToSession {
            applyFontSize(to: session)
        }
    }

    func applyFontSize(to session: EditorSession) {
        let font = NSFont.monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
        session.textView.font = font
        var attrs = session.textView.typingAttributes
        attrs[.font] = font
        session.textView.typingAttributes = attrs
        applyTheme(to: session)
    }
}

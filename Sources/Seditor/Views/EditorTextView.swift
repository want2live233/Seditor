import AppKit

@MainActor
final class EditorTextView: NSTextView {
    var currentLineBackgroundColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.14)
    var caretColor: NSColor = NSColor.systemBlue
    var caretWidthScale: CGFloat = 1.6
    var caretHeightScale: CGFloat = 1.25

    private var currentCaretDrawRect: NSRect?
    private var caretVisible = true
    private var blinkTimer: Timer?
    private var selectionDidChangeObserver: NSObjectProtocol?
    private let blinkInterval: TimeInterval = 0.75

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installSelectionObserverIfNeeded()
        refreshCaretBlinkState()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            stopCaretBlink()
            removeSelectionObserver()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted {
            resetCaretBlink()
        }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted {
            stopCaretBlink()
            caretVisible = false
            invalidateCaretRegion()
        }
        return accepted
    }

    private func removeSelectionObserver() {
        if let selectionDidChangeObserver {
            NotificationCenter.default.removeObserver(selectionDidChangeObserver)
            self.selectionDidChangeObserver = nil
        }
    }

    private func installSelectionObserverIfNeeded() {
        removeSelectionObserver()

        selectionDidChangeObserver = NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resetCaretBlink()
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard
            caretVisible,
            let caretRect = currentCaretDrawRect,
            selectedRange().length == 0,
            window?.firstResponder === self,
            dirtyRect.intersects(caretRect)
        else { return }

        let context = NSGraphicsContext.current
        let oldAntialias = context?.shouldAntialias ?? true
        context?.shouldAntialias = false
        caretColor.setFill()
        caretRect.fill()
        context?.shouldAntialias = oldAntialias
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard let highlightRect = currentLineRect() else { return }
        currentLineBackgroundColor.setFill()
        highlightRect.fill()
    }

    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        let previousRect = currentCaretDrawRect
        let nextRect = scaledCaretRect(for: rect)

        if let previousRect, !previousRect.equalTo(nextRect) {
            setNeedsDisplay(previousRect.insetBy(dx: -2, dy: -2).integral)
        }

        currentCaretDrawRect = nextRect
        setNeedsDisplay(nextRect.insetBy(dx: -2, dy: -2).integral)

    }

    private func scaledCaretRect(for rect: NSRect) -> NSRect {
        let scaledWidth = rect.width * max(caretWidthScale, 1.0)
        let scaledHeight = rect.height * max(caretHeightScale, 1.0)
        let xOffset = (scaledWidth - rect.width) / 2.0
        let yOffset = (scaledHeight - rect.height) / 2.0

        var drawRect = NSRect(
            x: rect.origin.x - xOffset,
            y: rect.origin.y - yOffset,
            width: scaledWidth,
            height: scaledHeight
        )

        // Keep the custom caret within the current line fragment so blink-off clears cleanly.
        if let lineRect = currentInsertionLineFragmentRect() {
            drawRect = drawRect.intersection(lineRect)
        }

        return drawRect.integral
    }

    private func resetCaretBlink() {
        caretVisible = true
        startCaretBlinkIfNeeded()
        invalidateCaretRegion()
    }

    private func refreshCaretBlinkState() {
        if window?.firstResponder === self, selectedRange().length == 0 {
            startCaretBlinkIfNeeded()
        } else {
            stopCaretBlink()
            caretVisible = false
        }
        invalidateCaretRegion()
    }

    private func startCaretBlinkIfNeeded() {
        guard blinkTimer == nil else { return }
        let timer = Timer(timeInterval: blinkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.window?.firstResponder === self, self.selectedRange().length == 0 else {
                    self.caretVisible = false
                    self.stopCaretBlink()
                    self.invalidateCaretRegion()
                    return
                }

                self.caretVisible.toggle()
                self.invalidateCaretRegion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        blinkTimer = timer
    }

    private func stopCaretBlink() {
        blinkTimer?.invalidate()
        blinkTimer = nil
    }

    private func invalidateCaretRegion() {
        guard let caretRect = currentCaretDrawRect else { return }
        setNeedsDisplay(caretRect.insetBy(dx: -2, dy: -2).integral)
    }

    private func currentInsertionLineFragmentRect() -> NSRect? {
        guard let layoutManager = layoutManager else { return nil }

        let text = string as NSString
        let location = min(selectedRange().location, text.length)

        let fragmentRect: NSRect
        if location < text.length {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: location)
            fragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: nil,
                withoutAdditionalLayout: true
            )
        } else {
            let extraRect = layoutManager.extraLineFragmentRect
            if !extraRect.isEmpty {
                fragmentRect = extraRect
            } else if location > 0 {
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: location - 1)
                fragmentRect = layoutManager.lineFragmentRect(
                    forGlyphAt: glyphIndex,
                    effectiveRange: nil,
                    withoutAdditionalLayout: true
                )
            } else {
                return nil
            }
        }

        var rect = fragmentRect
        rect.origin.y += textContainerInset.height
        return rect
    }

    private func currentLineRect() -> NSRect? {
        guard let layoutManager = layoutManager else { return nil }

        let text = string as NSString
        let location = min(selectedRange().location, text.length)
        let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
        let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)

        let lineRect: NSRect
        if glyphRange.length > 0 {
            var rect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: nil,
                withoutAdditionalLayout: true
            )
            rect.origin.y += textContainerInset.height
            lineRect = rect
        } else {
            // Trailing empty line after a final newline uses extra line fragment rect.
            var rect = layoutManager.extraLineFragmentRect
            if rect.isEmpty { return nil }
            rect.origin.y += textContainerInset.height
            lineRect = rect
        }

        return NSRect(x: 0, y: lineRect.minY, width: bounds.width, height: lineRect.height)
    }
}

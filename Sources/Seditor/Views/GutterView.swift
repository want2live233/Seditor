import AppKit

@MainActor
final class GutterView: NSView {
    weak var textView: NSTextView?
    var backgroundColor: NSColor = .windowBackgroundColor
    var lineNumberColor: NSColor = .secondaryLabelColor
    var highlightedLineNumberColor: NSColor = .labelColor
    var highlightedLineBackgroundColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.20)
    var lineNumberFont: NSFont = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private var cachedLineStartIndices: [Int] = [0]
    private var cachedLineIndexTextLength = -1
    private var cachedNumberSizes: [Int: CGSize] = [:]
    private var cachedNumberFontSize: CGFloat = -1

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        dirtyRect.fill()

        // Draw separator first so highlighted rows can cover it and look continuous.
        NSColor.separatorColor.setStroke()
        let separator = NSBezierPath()
        separator.move(to: NSPoint(x: bounds.width - 1, y: 0))
        separator.line(to: NSPoint(x: bounds.width - 1, y: bounds.height))
        separator.stroke()

        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else { return }

        let visibleRect = textView.visibleRect
        ensureLineIndexCache(for: textView.string as NSString)
        ensureNumberSizeCacheFont()
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        if glyphRange.length == 0 {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: lineNumberColor
            ]
            let highlightedAttrs: [NSAttributedString.Key: Any] = [
                .font: lineNumberFont,
                .foregroundColor: highlightedLineNumberColor
            ]
            let label = "1" as NSString
            let size = cachedNumberSize(for: 1, attrs: attrs)
            let x = max(0, (bounds.width - size.width) / 2)
            let y = textView.textContainerInset.height - visibleRect.minY
            highlightedLineBackgroundColor.setFill()
            let badgeRect = NSRect(x: 0, y: y, width: bounds.width, height: max(16, size.height))
            badgeRect.fill()
            label.draw(at: NSPoint(x: x, y: y), withAttributes: highlightedAttrs)
            return
        }

        let textNSString = textView.string as NSString
        let firstCharIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        var lineNumber = lineNumberForCharacterIndex(textNSString, firstCharIndex)
        var glyphIndex = glyphRange.location
        let currentLineNumber = currentLineNumberForTextView(textView)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: lineNumberFont,
            .foregroundColor: lineNumberColor
        ]
        var drawnLineNumbers = Set<Int>()

        while glyphIndex < NSMaxRange(glyphRange) {
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let lineCharRange = textNSString.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineGlyphRange = layoutManager.glyphRange(forCharacterRange: lineCharRange, actualCharacterRange: nil)

            var lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: lineGlyphRange.location,
                effectiveRange: nil,
                withoutAdditionalLayout: true
            )
            lineRect.origin.y += textView.textContainerInset.height

            let y = lineRect.minY - visibleRect.minY
            let label = "\(lineNumber)" as NSString
            let size = cachedNumberSize(for: lineNumber, attrs: attrs)
            let x = max(0, (bounds.width - size.width) / 2)
            if lineNumber == currentLineNumber {
                highlightedLineBackgroundColor.setFill()
                let badgeRect = NSRect(x: 0, y: y, width: bounds.width, height: max(16, lineRect.height))
                badgeRect.fill()
                let highlightedAttrs: [NSAttributedString.Key: Any] = [
                    .font: lineNumberFont,
                    .foregroundColor: highlightedLineNumberColor
                ]
                label.draw(at: NSPoint(x: x, y: y), withAttributes: highlightedAttrs)
            } else {
                label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
            drawnLineNumbers.insert(lineNumber)

            glyphIndex = NSMaxRange(lineGlyphRange)
            lineNumber += 1
        }

        // Draw trailing/current empty line number (e.g. after pressing Return at EOF).
        if textView.string.hasSuffix("\n") {
            let trailingLineNumber = lineNumberForCharacterIndex(textNSString, textNSString.length)
            if !drawnLineNumbers.contains(trailingLineNumber) {
                var extraRect = layoutManager.extraLineFragmentRect
                if !extraRect.isEmpty {
                    extraRect.origin.y += textView.textContainerInset.height
                    let y = extraRect.minY - visibleRect.minY
                    if y + extraRect.height >= 0 && y <= bounds.height {
                        let label = "\(trailingLineNumber)" as NSString
                        let size = cachedNumberSize(for: trailingLineNumber, attrs: attrs)
                        let x = max(0, (bounds.width - size.width) / 2)
                        if trailingLineNumber == currentLineNumber {
                            highlightedLineBackgroundColor.setFill()
                            let badgeRect = NSRect(x: 0, y: y, width: bounds.width, height: max(16, extraRect.height))
                            badgeRect.fill()
                            let highlightedAttrs: [NSAttributedString.Key: Any] = [
                                .font: lineNumberFont,
                                .foregroundColor: highlightedLineNumberColor
                            ]
                            label.draw(at: NSPoint(x: x, y: y), withAttributes: highlightedAttrs)
                        } else {
                            label.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
                        }
                    }
                }
            }
        }
    }

    private func lineNumberForCharacterIndex(_ text: NSString, _ index: Int) -> Int {
        guard !cachedLineStartIndices.isEmpty else { return 1 }
        var low = 0
        var high = cachedLineStartIndices.count - 1
        var answer = 0
        while low <= high {
            let mid = (low + high) / 2
            if cachedLineStartIndices[mid] <= index {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer + 1
    }

    private func currentLineNumberForTextView(_ textView: NSTextView) -> Int {
        let text = textView.string as NSString
        let location = min(textView.selectedRange().location, text.length)
        return lineNumberForCharacterIndex(text, location)
    }

    func invalidateCaches() {
        cachedLineIndexTextLength = -1
        cachedLineStartIndices = [0]
        cachedNumberSizes.removeAll(keepingCapacity: true)
    }

    private func ensureLineIndexCache(for text: NSString) {
        if cachedLineIndexTextLength == text.length {
            return
        }

        cachedLineIndexTextLength = text.length
        cachedLineStartIndices = [0]
        if text.length == 0 {
            return
        }

        for i in 0..<text.length where text.character(at: i) == 10 {
            let next = i + 1
            if next <= text.length {
                cachedLineStartIndices.append(next)
            }
        }
    }

    private func ensureNumberSizeCacheFont() {
        if cachedNumberFontSize != lineNumberFont.pointSize {
            cachedNumberFontSize = lineNumberFont.pointSize
            cachedNumberSizes.removeAll(keepingCapacity: true)
        }
    }

    private func cachedNumberSize(for lineNumber: Int, attrs: [NSAttributedString.Key: Any]) -> CGSize {
        if let size = cachedNumberSizes[lineNumber] {
            return size
        }
        let size = "\(lineNumber)".size(withAttributes: attrs)
        cachedNumberSizes[lineNumber] = size
        return size
    }
}

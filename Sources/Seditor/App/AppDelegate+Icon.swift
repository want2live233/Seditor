import AppKit

@MainActor
extension AppDelegate {
    func configureAppIcon() {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
            return
        }

        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let unifiedBlue = NSColor(calibratedRed: 0.18, green: 0.50, blue: 0.95, alpha: 1)
        let outerRect = rect.insetBy(dx: 40, dy: 40)
        let bgPath = NSBezierPath(roundedRect: outerRect, xRadius: 95, yRadius: 95)
        unifiedBlue.setFill()
        bgPath.fill()

        let accentRect = rect.insetBy(dx: 114, dy: 114)
        let accentPath = NSBezierPath(roundedRect: accentRect, xRadius: 76, yRadius: 76)
        unifiedBlue.setFill()
        accentPath.fill()

        let title = "S" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 286, weight: .heavy),
            .foregroundColor: NSColor.white
        ]
        let titleSize = title.size(withAttributes: attrs)
        let titlePoint = NSPoint(
            x: (size.width - titleSize.width) / 2,
            y: (size.height - titleSize.height) / 2 - 8
        )
        title.draw(at: titlePoint, withAttributes: attrs)

        NSApp.applicationIconImage = image
    }
}

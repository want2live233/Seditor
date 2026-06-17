import AppKit
import CoreFoundation

@MainActor
extension AppDelegate {
    private enum PreferenceKey {
        static let theme = "settings.theme"
        static let fontSize = "settings.fontSize"
        static let defaultEncoding = "settings.defaultEncoding"
        static let defaultLineEnding = "settings.defaultLineEnding"
    }

    @objc func openSettings() {
        if let window = settingsWindow {
            syncSettingsUIFromCurrentPreferences()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 220))

        let themeLabel = makeSettingsLabel(L10n.t("settings.theme", "Theme"))
        let fontLabel = makeSettingsLabel(L10n.t("settings.fontSize", "Editor Font Size"))
        let encodingLabel = makeSettingsLabel(L10n.t("settings.defaultEncoding", "Default Encoding"))
        let lineEndingLabel = makeSettingsLabel(L10n.t("settings.defaultLineEnding", "Default Line Endings"))

        settingsThemePopup.removeAllItems()
        settingsThemePopup.addItems(withTitles: [
            L10n.t("settings.theme.system", "System"),
            L10n.t("settings.theme.light", "Light"),
            L10n.t("settings.theme.dark", "Dark")
        ])
        settingsThemePopup.target = self
        settingsThemePopup.action = #selector(changeSettingsTheme(_:))
        settingsThemePopup.setAccessibilityLabel(L10n.t("settings.theme", "Theme"))

        settingsFontField.isEditable = false
        settingsFontField.isBordered = true
        settingsFontField.alignment = .center
        settingsFontField.setAccessibilityLabel(L10n.t("settings.fontSize", "Editor Font Size"))

        settingsFontStepper.minValue = 10
        settingsFontStepper.maxValue = 42
        settingsFontStepper.increment = 1
        settingsFontStepper.target = self
        settingsFontStepper.action = #selector(changeSettingsFontSize(_:))
        settingsFontStepper.setAccessibilityLabel(L10n.t("settings.fontSize", "Editor Font Size"))

        settingsEncodingPopup.removeAllItems()
        for (title, encoding) in settingsEncodingOptions() {
            settingsEncodingPopup.addItem(withTitle: title)
            settingsEncodingPopup.lastItem?.representedObject = encoding.rawValue
        }
        settingsEncodingPopup.target = self
        settingsEncodingPopup.action = #selector(changeSettingsDefaultEncoding(_:))
        settingsEncodingPopup.setAccessibilityLabel(L10n.t("settings.defaultEncoding", "Default Encoding"))
        settingsEncodingPopup.setAccessibilityHelp(L10n.t("settings.defaultEncoding.help", "Applies to newly created tabs and files."))
        settingsEncodingPopup.toolTip = L10n.t("settings.defaultEncoding.help", "Applies to newly created tabs and files.")

        settingsLineEndingPopup.removeAllItems()
        settingsLineEndingPopup.addItem(withTitle: "LF")
        settingsLineEndingPopup.lastItem?.representedObject = LineEndingStyle.lf.rawValue
        settingsLineEndingPopup.addItem(withTitle: "CRLF")
        settingsLineEndingPopup.lastItem?.representedObject = LineEndingStyle.crlf.rawValue
        settingsLineEndingPopup.target = self
        settingsLineEndingPopup.action = #selector(changeSettingsDefaultLineEnding(_:))
        settingsLineEndingPopup.setAccessibilityLabel(L10n.t("settings.defaultLineEnding", "Default Line Endings"))
        settingsLineEndingPopup.setAccessibilityHelp(L10n.t("settings.defaultLineEnding.help", "Applies to newly created tabs and files."))
        settingsLineEndingPopup.toolTip = L10n.t("settings.defaultLineEnding.help", "Applies to newly created tabs and files.")

        let fontRow = NSStackView(views: [settingsFontField, settingsFontStepper])
        fontRow.orientation = .horizontal
        fontRow.spacing = 10
        fontRow.distribution = .fillProportionally

        let grid = NSGridView(views: [
            [themeLabel, settingsThemePopup],
            [fontLabel, fontRow],
            [encodingLabel, settingsEncodingPopup],
            [lineEndingLabel, settingsLineEndingPopup]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.xPlacement = .fill
        grid.yPlacement = .center
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill

        panel.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20)
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("settings.title", "Settings")
        window.contentView = panel
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.initialFirstResponder = settingsThemePopup
        settingsThemePopup.nextKeyView = settingsFontStepper
        settingsFontStepper.nextKeyView = settingsEncodingPopup
        settingsEncodingPopup.nextKeyView = settingsLineEndingPopup
        settingsLineEndingPopup.nextKeyView = settingsThemePopup
        settingsWindow = window

        syncSettingsUIFromCurrentPreferences()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadPreferences() {
        let storedTheme = userDefaults.string(forKey: PreferenceKey.theme)
        switch storedTheme {
        case "light":
            editorTheme = .light
        case "dark":
            editorTheme = .dark
        default:
            editorTheme = .system
        }

        let storedFontSize = userDefaults.double(forKey: PreferenceKey.fontSize)
        if storedFontSize >= 10, storedFontSize <= 42 {
            editorFontSize = CGFloat(storedFontSize)
        }

        let storedEncoding = userDefaults.integer(forKey: PreferenceKey.defaultEncoding)
        if storedEncoding != 0 {
            defaultFileEncoding = String.Encoding(rawValue: UInt(storedEncoding))
        } else {
            defaultFileEncoding = .utf8
        }

        if let storedLineEnding = userDefaults.string(forKey: PreferenceKey.defaultLineEnding),
           let style = LineEndingStyle(rawValue: storedLineEnding) {
            defaultLineEnding = style
        } else {
            defaultLineEnding = .lf
        }
    }

    @objc func changeSettingsTheme(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 1:
            editorTheme = .light
        case 2:
            editorTheme = .dark
        default:
            editorTheme = .system
        }
        userDefaults.set(themeStorageValue(editorTheme), forKey: PreferenceKey.theme)
        applyTheme()
    }

    @objc func changeSettingsFontSize(_ sender: NSStepper) {
        editorFontSize = max(10, min(42, CGFloat(sender.integerValue)))
        userDefaults.set(Double(editorFontSize), forKey: PreferenceKey.fontSize)
        applyFontSize()
        syncSettingsUIFromCurrentPreferences()
    }

    @objc func changeSettingsDefaultEncoding(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? UInt else { return }
        defaultFileEncoding = String.Encoding(rawValue: raw)
        userDefaults.set(Int(raw), forKey: PreferenceKey.defaultEncoding)
    }

    @objc func changeSettingsDefaultLineEnding(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let style = LineEndingStyle(rawValue: raw) else { return }
        defaultLineEnding = style
        userDefaults.set(raw, forKey: PreferenceKey.defaultLineEnding)
    }

    func syncSettingsUIFromCurrentPreferences() {
        switch editorTheme {
        case .system:
            settingsThemePopup.selectItem(at: 0)
        case .light:
            settingsThemePopup.selectItem(at: 1)
        case .dark:
            settingsThemePopup.selectItem(at: 2)
        }

        let fontValue = Int(round(editorFontSize))
        settingsFontStepper.integerValue = fontValue
        settingsFontField.stringValue = String(format: L10n.t("settings.font.pt", "%d pt"), fontValue)

        if let index = settingsEncodingOptions().firstIndex(where: { $0.1 == defaultFileEncoding }) {
            settingsEncodingPopup.selectItem(at: index)
        } else {
            settingsEncodingPopup.selectItem(at: 0)
        }

        settingsLineEndingPopup.selectItem(withTitle: defaultLineEnding == .crlf ? "CRLF" : "LF")
    }

    private func makeSettingsLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.alignment = .right
        return label
    }

    private func settingsEncodingOptions() -> [(String, String.Encoding)] {
        [
            ("UTF-8", .utf8),
            ("GB18030", encodingFromCF(0x0632)),
            ("GBK", encodingFromCF(0x0631)),
            ("GB2312", encodingFromCF(0x0630))
        ]
    }

    private func encodingFromCF(_ value: CFStringEncoding) -> String.Encoding {
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(value))
    }

    private func themeStorageValue(_ theme: EditorTheme) -> String {
        switch theme {
        case .system: return "system"
        case .light: return "light"
        case .dark: return "dark"
        }
    }
}

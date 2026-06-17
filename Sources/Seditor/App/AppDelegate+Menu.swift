import AppKit

@MainActor
extension AppDelegate {
    func setupMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        let appName = appDisplayName()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let aboutItem = appMenu.addItem(withTitle: String(format: L10n.t("menu.about", "About %@"), appName), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        aboutItem.target = nil
        appMenu.addItem(.separator())

        let settingsItem = appMenu.addItem(withTitle: L10n.t("menu.settings", "Settings..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: L10n.t("menu.services", "Services"), action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: L10n.t("menu.services", "Services"))
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())

        let hideItem = appMenu.addItem(withTitle: String(format: L10n.t("menu.hide", "Hide %@"), appName), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.target = nil

        let hideOthersItem = appMenu.addItem(withTitle: L10n.t("menu.hideOthers", "Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.target = nil
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]

        let showAllItem = appMenu.addItem(withTitle: L10n.t("menu.showAll", "Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        showAllItem.target = nil
        appMenu.addItem(.separator())

        let quitItem = appMenu.addItem(withTitle: String(format: L10n.t("menu.quit", "Quit %@"), appName), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = nil

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: L10n.t("menu.file", "File"))
        fileMenuItem.submenu = fileMenu

        let newItem = fileMenu.addItem(withTitle: L10n.t("menu.new", "New"), action: #selector(newDocument), keyEquivalent: "n")
        newItem.target = self

        fileMenu.addItem(.separator())

        let openItem = fileMenu.addItem(withTitle: L10n.t("menu.open", "Open..."), action: #selector(openDocument), keyEquivalent: "o")
        openItem.target = self

        let saveItem = fileMenu.addItem(withTitle: L10n.t("menu.save", "Save"), action: #selector(saveDocument), keyEquivalent: "s")
        saveItem.target = self

        let saveAsItem = fileMenu.addItem(withTitle: L10n.t("menu.saveAs", "Save As..."), action: #selector(saveDocumentAs), keyEquivalent: "S")
        saveAsItem.target = self

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L10n.t("menu.edit", "Edit"))
        editMenuItem.submenu = editMenu

        let undo = editMenu.addItem(withTitle: L10n.t("menu.undo", "Undo"), action: #selector(performUndo), keyEquivalent: "z")
        undo.target = self
        let redo = editMenu.addItem(withTitle: L10n.t("menu.redo", "Redo"), action: #selector(performRedo), keyEquivalent: "Z")
        redo.target = self
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())

        let cut = editMenu.addItem(withTitle: L10n.t("menu.cut", "Cut"), action: #selector(performCut), keyEquivalent: "x")
        cut.target = self
        let copy = editMenu.addItem(withTitle: L10n.t("menu.copy", "Copy"), action: #selector(performCopy), keyEquivalent: "c")
        copy.target = self
        let paste = editMenu.addItem(withTitle: L10n.t("menu.paste", "Paste"), action: #selector(performPaste), keyEquivalent: "v")
        paste.target = self
        editMenu.addItem(.separator())

        let selectAll = editMenu.addItem(withTitle: L10n.t("menu.selectAll", "Select All"), action: #selector(performSelectAll), keyEquivalent: "a")
        selectAll.target = self
        editMenu.addItem(.separator())

        let goToLineItem = editMenu.addItem(withTitle: L10n.t("menu.goToLine", "Go to Line..."), action: #selector(goToLine), keyEquivalent: "l")
        goToLineItem.target = self
        editMenu.addItem(.separator())

        let findItem = editMenu.addItem(withTitle: L10n.t("menu.find", "Find..."), action: #selector(performFindAction(_:)), keyEquivalent: "f")
        findItem.target = self
        findItem.tag = NSTextFinder.Action.showFindInterface.rawValue

        let findNextItem = editMenu.addItem(withTitle: L10n.t("menu.findNext", "Find Next"), action: #selector(performFindAction(_:)), keyEquivalent: "g")
        findNextItem.target = self
        findNextItem.tag = NSTextFinder.Action.nextMatch.rawValue

        let findPreviousItem = editMenu.addItem(withTitle: L10n.t("menu.findPrev", "Find Previous"), action: #selector(performFindAction(_:)), keyEquivalent: "G")
        findPreviousItem.target = self
        findPreviousItem.tag = NSTextFinder.Action.previousMatch.rawValue
        findPreviousItem.keyEquivalentModifierMask = [.command, .shift]

        let useSelectionItem = editMenu.addItem(withTitle: L10n.t("menu.findUseSelection", "Use Selection for Find"), action: #selector(performFindAction(_:)), keyEquivalent: "e")
        useSelectionItem.target = self
        useSelectionItem.tag = NSTextFinder.Action.setSearchString.rawValue
        editMenu.addItem(.separator())

        let replaceItem = editMenu.addItem(withTitle: L10n.t("menu.replacePanel", "Find and Replace..."), action: #selector(performFindAction(_:)), keyEquivalent: "f")
        replaceItem.target = self
        replaceItem.tag = NSTextFinder.Action.showReplaceInterface.rawValue
        replaceItem.keyEquivalentModifierMask = [.command, .option]

        let replaceNextItem = editMenu.addItem(withTitle: L10n.t("menu.replace", "Replace"), action: #selector(performFindAction(_:)), keyEquivalent: "")
        replaceNextItem.target = self
        replaceNextItem.tag = NSTextFinder.Action.replace.rawValue

        let replaceAllItem = editMenu.addItem(withTitle: L10n.t("menu.replaceAll", "Replace All"), action: #selector(performFindAction(_:)), keyEquivalent: "")
        replaceAllItem.target = self
        replaceAllItem.tag = NSTextFinder.Action.replaceAll.rawValue

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: L10n.t("menu.view", "View"))
        viewMenuItem.submenu = viewMenu

        let incFont = viewMenu.addItem(withTitle: L10n.t("menu.increaseFont", "Increase Font Size"), action: #selector(increaseFontSize), keyEquivalent: "+")
        incFont.target = self

        let decFont = viewMenu.addItem(withTitle: L10n.t("menu.decreaseFont", "Decrease Font Size"), action: #selector(decreaseFontSize), keyEquivalent: "-")
        decFont.target = self

        viewMenu.addItem(.separator())
        let fullScreenItem = viewMenu.addItem(withTitle: L10n.t("menu.enterFullScreen", "Enter Full Screen"), action: #selector(toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreenItem.target = self
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]

        let tabMenuItem = NSMenuItem()
        mainMenu.addItem(tabMenuItem)
        let tabMenu = NSMenu(title: L10n.t("menu.tab", "Tab"))
        tabMenuItem.submenu = tabMenu

        let newTabItem = tabMenu.addItem(withTitle: L10n.t("menu.newTab", "New Tab"), action: #selector(newTab), keyEquivalent: "t")
        newTabItem.target = self

        let closeTabItem = tabMenu.addItem(withTitle: L10n.t("menu.closeTab", "Close Tab"), action: #selector(closeTab), keyEquivalent: "w")
        closeTabItem.target = self

        let closeAllTabsItem = tabMenu.addItem(withTitle: L10n.t("menu.closeAllTabs", "Close All Tabs"), action: #selector(closeAllTabs), keyEquivalent: "w")
        closeAllTabsItem.target = self
        closeAllTabsItem.keyEquivalentModifierMask = [.command, .option]

        let nextTabItem = tabMenu.addItem(withTitle: L10n.t("menu.nextTab", "Next Tab"), action: #selector(nextTab), keyEquivalent: "]")
        nextTabItem.target = self
        nextTabItem.keyEquivalentModifierMask = [.command, .shift]

        let prevTabItem = tabMenu.addItem(withTitle: L10n.t("menu.prevTab", "Previous Tab"), action: #selector(previousTab), keyEquivalent: "[")
        prevTabItem.target = self
        prevTabItem.keyEquivalentModifierMask = [.command, .shift]

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: L10n.t("menu.window", "Window"))
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        let minimizeItem = windowMenu.addItem(withTitle: L10n.t("menu.minimize", "Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        minimizeItem.target = nil

        let zoomItem = windowMenu.addItem(withTitle: L10n.t("menu.zoom", "Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        zoomItem.target = nil

        windowMenu.addItem(.separator())
        let bringAllToFrontItem = windowMenu.addItem(withTitle: L10n.t("menu.bringAllToFront", "Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        bringAllToFrontItem.target = nil

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: L10n.t("menu.help", "Help"))
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        let helpItem = helpMenu.addItem(withTitle: L10n.t("menu.appHelp", "Seditor Help"), action: #selector(showHelp), keyEquivalent: "?")
        helpItem.target = self
    }

    @objc func newDocument() {
        createNewTab(select: true)
        focusCurrentEditor()
    }

    @objc func newTab() {
        createNewTab(select: true)
        focusCurrentEditor()
    }

    @objc func closeTab() {
        guard tabView.numberOfTabViewItems > 0 else {
            window?.performClose(nil)
            return
        }
        closeCurrentTab()
    }

    @objc func toggleFullScreen(_ sender: Any?) {
        window?.toggleFullScreen(sender)
    }

    @objc func nextTab() {
        let count = tabView.numberOfTabViewItems
        guard count > 1, let current = currentTabItem() else { return }
        let idx = tabView.indexOfTabViewItem(current)
        guard idx >= 0 else { return }
        let next = (idx + 1) % count
        tabView.selectTabViewItem(at: next)
        updateWindowTitle()
        focusCurrentEditor()
    }

    @objc func previousTab() {
        let count = tabView.numberOfTabViewItems
        guard count > 1, let current = currentTabItem() else { return }
        let idx = tabView.indexOfTabViewItem(current)
        guard idx >= 0 else { return }
        let prev = (idx - 1 + count) % count
        tabView.selectTabViewItem(at: prev)
        updateWindowTitle()
        focusCurrentEditor()
    }

    @objc func increaseFontSize() {
        editorFontSize = min(42, editorFontSize + 1)
        userDefaults.set(Double(editorFontSize), forKey: "settings.fontSize")
        applyFontSize()
    }

    @objc func decreaseFontSize() {
        editorFontSize = max(10, editorFontSize - 1)
        userDefaults.set(Double(editorFontSize), forKey: "settings.fontSize")
        applyFontSize()
    }

    @objc func setThemeSystem() {
        editorTheme = .system
        userDefaults.set("system", forKey: "settings.theme")
        applyTheme()
    }

    @objc func setThemeLight() {
        editorTheme = .light
        userDefaults.set("light", forKey: "settings.theme")
        applyTheme()
    }

    @objc func setThemeDark() {
        editorTheme = .dark
        userDefaults.set("dark", forKey: "settings.theme")
        applyTheme()
    }

    @objc func performUndo(_ sender: Any?) {
        currentSession()?.textView.undoManager?.undo()
    }

    @objc func performRedo(_ sender: Any?) {
        currentSession()?.textView.undoManager?.redo()
    }

    @objc func performCut(_ sender: Any?) {
        currentSession()?.textView.cut(sender)
    }

    @objc func performCopy(_ sender: Any?) {
        currentSession()?.textView.copy(sender)
    }

    @objc func performPaste(_ sender: Any?) {
        currentSession()?.textView.paste(sender)
    }

    @objc func performSelectAll(_ sender: Any?) {
        currentSession()?.textView.selectAll(sender)
    }

    @objc func goToLine() {
        guard let session = currentSession() else { return }

        let alert = NSAlert()
        alert.messageText = L10n.t("goto.title", "Go to Line")
        alert.informativeText = L10n.t("goto.hint", "Enter line number, or line:column (e.g. 128 or 128:16).")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.t("goto.go", "Go"))
        alert.addButton(withTitle: L10n.t("common.cancel", "Cancel"))

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.placeholderString = "line[:column]"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let raw = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let (line, column) = parseLineColumn(raw), line >= 1 else {
            NSSound.beep()
            return
        }

        moveCaret(toLine: line, column: column, in: session.textView)
    }

    @objc func performFindAction(_ sender: Any?) {
        guard let session = currentSession() else { return }
        guard let menuItem = sender as? NSMenuItem else { return }
        session.textView.performTextFinderAction(menuItem)
    }

    @objc func showHelp() {
        if Bundle.main.path(forResource: "SeditorHelp", ofType: "help") != nil {
            NSHelpManager.shared.openHelpAnchor("index", inBook: "Seditor Help")
            return
        }

        if let existingHelpWindow = helpWindow {
            existingHelpWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let helpText = L10n.t("help.shortcuts.body", """
        Keyboard Shortcuts

        Command+N   New
        Command+O   Open
        Command+S   Save
        Shift+Command+S   Save As
        Command+L   Go to Line
        Command+F   Find
        Option+Command+F   Replace
        Command+G   Find Next
        Shift+Command+G   Find Previous
        Command+T   New Tab
        Command+W   Close Tab / Close Window
        Option+Command+W   Close All Tabs
        Control+Command+F   Enter/Exit Full Screen
        """)

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 320))
        textView.string = helpText
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 14, height: 14)

        let scrollView = NSScrollView(frame: textView.frame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView
        scrollView.drawsBackground = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 320))
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        helpWindow.title = L10n.t("help.title", "Seditor Help")
        helpWindow.contentView = contentView
        helpWindow.center()
        helpWindow.isReleasedWhenClosed = false
        helpWindow.delegate = self
        self.helpWindow = helpWindow

        helpWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func parseLineColumn(_ raw: String) -> (Int, Int?)? {
        if raw.isEmpty { return nil }
        let separators = CharacterSet(charactersIn: ":,")
        let parts = raw.components(separatedBy: separators).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        guard let first = parts.first, let line = Int(first), line >= 1 else { return nil }
        if parts.count <= 1 {
            return (line, nil)
        }
        guard let column = Int(parts[1]), column >= 1 else { return nil }
        return (line, column)
    }

    private func moveCaret(toLine line: Int, column: Int?, in textView: NSTextView) {
        let text = textView.string as NSString
        let length = text.length

        var lineStart = 0
        var currentLine = 1
        while currentLine < line && lineStart < length {
            let range = text.lineRange(for: NSRange(location: lineStart, length: 0))
            let next = NSMaxRange(range)
            if next <= lineStart { break }
            lineStart = next
            currentLine += 1
        }

        if currentLine < line {
            NSSound.beep()
            return
        }

        var start = 0
        var end = 0
        var contentsEnd = 0
        text.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))

        let targetColumn = max(1, column ?? 1)
        let maxColumnLocation = contentsEnd
        let target = min(start + targetColumn - 1, maxColumnLocation)

        textView.setSelectedRange(NSRange(location: target, length: 0))
        textView.scrollRangeToVisible(NSRange(location: target, length: 0))
        textView.window?.makeFirstResponder(textView)
        updateStatusBarForCurrentSession()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action

        if action == #selector(closeTab) {
            menuItem.title = tabView.numberOfTabViewItems > 0 ? L10n.t("menu.closeTab", "Close Tab") : L10n.t("menu.closeWindow", "Close Window")
            return window != nil
        }
        if action == #selector(closeAllTabs) {
            return tabView.numberOfTabViewItems > 0
        }
        if action == #selector(nextTab) || action == #selector(previousTab) {
            return tabView.numberOfTabViewItems > 1
        }
        if action == #selector(toggleFullScreen(_:)) {
            let isFullScreen = window?.styleMask.contains(.fullScreen) == true
            menuItem.title = isFullScreen ? L10n.t("menu.exitFullScreen", "Exit Full Screen") : L10n.t("menu.enterFullScreen", "Enter Full Screen")
            return window != nil
        }

        guard let session = currentSession() else {
            if action == #selector(saveDocument) ||
                action == #selector(saveDocumentAs) ||
                action == #selector(performUndo(_:)) ||
                action == #selector(performRedo(_:)) ||
                action == #selector(performCut(_:)) ||
                action == #selector(performCopy(_:)) ||
                action == #selector(performPaste(_:)) ||
                action == #selector(performSelectAll(_:)) ||
                action == #selector(goToLine) ||
                action == #selector(performFindAction(_:)) {
                return false
            }
            return true
        }

        if action == #selector(performUndo(_:)) {
            return session.textView.undoManager?.canUndo == true
        }
        if action == #selector(performRedo(_:)) {
            return session.textView.undoManager?.canRedo == true
        }
        if action == #selector(performCopy(_:)) {
            return session.textView.selectedRange().length > 0
        }
        if action == #selector(performFindAction(_:)) {
            return true
        }

        return true
    }

    private func appDisplayName() -> String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !bundleName.isEmpty {
            return bundleName
        }
        return "Seditor"
    }
}

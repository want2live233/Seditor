import AppKit

@MainActor
extension AppDelegate {
    func setupMenu() {
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Seditor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let openItem = fileMenu.addItem(withTitle: "Open...", action: #selector(openDocument), keyEquivalent: "o")
        openItem.target = self

        let saveItem = fileMenu.addItem(withTitle: "Save", action: #selector(saveDocument), keyEquivalent: "s")
        saveItem.target = self

        let saveAsItem = fileMenu.addItem(withTitle: "Save As...", action: #selector(saveDocumentAs), keyEquivalent: "S")
        saveAsItem.target = self

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        let undo = editMenu.addItem(withTitle: "Undo", action: #selector(performUndo), keyEquivalent: "z")
        undo.target = self
        let redo = editMenu.addItem(withTitle: "Redo", action: #selector(performRedo), keyEquivalent: "Z")
        redo.target = self
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())

        let cut = editMenu.addItem(withTitle: "Cut", action: #selector(performCut), keyEquivalent: "x")
        cut.target = self
        let copy = editMenu.addItem(withTitle: "Copy", action: #selector(performCopy), keyEquivalent: "c")
        copy.target = self
        let paste = editMenu.addItem(withTitle: "Paste", action: #selector(performPaste), keyEquivalent: "v")
        paste.target = self
        editMenu.addItem(.separator())

        let selectAll = editMenu.addItem(withTitle: "Select All", action: #selector(performSelectAll), keyEquivalent: "a")
        selectAll.target = self

        let tabMenuItem = NSMenuItem()
        mainMenu.addItem(tabMenuItem)
        let tabMenu = NSMenu(title: "Tab")
        tabMenuItem.submenu = tabMenu

        let newTabItem = tabMenu.addItem(withTitle: "New Tab", action: #selector(newTab), keyEquivalent: "t")
        newTabItem.target = self

        let closeTabItem = tabMenu.addItem(withTitle: "Close Tab", action: #selector(closeTab), keyEquivalent: "w")
        closeTabItem.target = self

        let nextTabItem = tabMenu.addItem(withTitle: "Next Tab", action: #selector(nextTab), keyEquivalent: "]")
        nextTabItem.target = self
        nextTabItem.keyEquivalentModifierMask = [.command, .shift]

        let prevTabItem = tabMenu.addItem(withTitle: "Previous Tab", action: #selector(previousTab), keyEquivalent: "[")
        prevTabItem.target = self
        prevTabItem.keyEquivalentModifierMask = [.command, .shift]

        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let incFont = viewMenu.addItem(withTitle: "Increase Font Size", action: #selector(increaseFontSize), keyEquivalent: "+")
        incFont.target = self

        let decFont = viewMenu.addItem(withTitle: "Decrease Font Size", action: #selector(decreaseFontSize), keyEquivalent: "-")
        decFont.target = self

        let appearanceMenuItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu(title: "Appearance")
        appearanceMenuItem.submenu = appearanceMenu
        viewMenu.addItem(appearanceMenuItem)

        let systemItem = appearanceMenu.addItem(withTitle: "System", action: #selector(setThemeSystem), keyEquivalent: "")
        systemItem.target = self

        let lightItem = appearanceMenu.addItem(withTitle: "Light", action: #selector(setThemeLight), keyEquivalent: "")
        lightItem.target = self

        let darkItem = appearanceMenu.addItem(withTitle: "Dark", action: #selector(setThemeDark), keyEquivalent: "")
        darkItem.target = self
    }

    @objc func newTab() {
        createNewTab(select: true)
        focusCurrentEditor()
    }

    @objc func closeTab() {
        closeCurrentTab()
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
        applyFontSize()
    }

    @objc func decreaseFontSize() {
        editorFontSize = max(10, editorFontSize - 1)
        applyFontSize()
    }

    @objc func setThemeSystem() {
        editorTheme = .system
        applyTheme()
    }

    @objc func setThemeLight() {
        editorTheme = .light
        applyTheme()
    }

    @objc func setThemeDark() {
        editorTheme = .dark
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
}

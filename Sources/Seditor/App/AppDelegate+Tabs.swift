import AppKit

@MainActor
extension AppDelegate {
    @discardableResult
    func createTab(
        autosaveURL: URL,
        initialContent: String,
        fileURL: URL?,
        preferredLabel: String?,
        select: Bool,
        persist: Bool = true
    ) -> EditorSession {
        let session = EditorSession(autosaveURL: autosaveURL)
        session.textView.delegate = self
        session.textView.string = initialContent
        session.currentFileURL = fileURL
        session.gutterView.invalidateCaches()

        applyTheme(to: session)
        applyFontSize(to: session)

        let item = NSTabViewItem(identifier: session.id.uuidString)
        if let preferredLabel, !preferredLabel.isEmpty {
            item.label = preferredLabel
        } else {
            item.label = "Untitled \(untitledCounter)"
            untitledCounter += 1
        }
        item.view = session.rootView

        tabView.addTabViewItem(item)
        if select {
            tabView.selectTabViewItem(item)
        }

        tabItemToSession[ObjectIdentifier(item)] = session
        textViewToSession[ObjectIdentifier(session.textView)] = session
        clipViewToSession[ObjectIdentifier(session.editorScrollView.contentView)] = session

        let clip = session.editorScrollView.contentView
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(editorDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clip
        )

        syncTabButtons()
        updateWindowTitle()
        requestRedraw(for: session, gutter: true, editor: true)
        if persist { persistWorkspaceState() }
        if select {
            DispatchQueue.main.async { [weak self] in
                self?.focusCurrentEditor()
            }
        }
        return session
    }

    func createNewTab(select: Bool) {
        let autosaveURL = autosaveDirectoryURL.appendingPathComponent("autosave-\(UUID().uuidString).txt")
        _ = createTab(
            autosaveURL: autosaveURL,
            initialContent: "",
            fileURL: nil,
            preferredLabel: nil,
            select: select
        )
    }

    func closeCurrentTab() {
        guard let item = currentTabItem() else { return }
        guard tabView.numberOfTabViewItems > 1 else { return }

        let key = ObjectIdentifier(item)
        if let session = tabItemToSession[key] {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: session.editorScrollView.contentView)
            textViewToSession.removeValue(forKey: ObjectIdentifier(session.textView))
            clipViewToSession.removeValue(forKey: ObjectIdentifier(session.editorScrollView.contentView))
            tabItemToSession.removeValue(forKey: key)
        }

        tabView.removeTabViewItem(item)
        syncTabButtons()
        updateWindowTitle()
        persistWorkspaceState()
        focusCurrentEditor()
    }

    func updateTabLabel(for session: EditorSession) {
        guard let item = tabView.tabViewItems.first(where: { tabItemToSession[ObjectIdentifier($0)] === session }) else { return }
        if let fileURL = session.currentFileURL {
            item.label = fileURL.lastPathComponent
        } else if item.label.isEmpty {
            item.label = "Untitled"
        }
        syncTabButtons()
        persistWorkspaceState()
    }

    func syncTabButtons() {
        let tabIDs = tabView.tabViewItems.compactMap { $0.identifier as? String }
        let validSet = Set(tabIDs)

        let staleIDs = tabButtonsByID.keys.filter { !validSet.contains($0) }
        for id in staleIDs {
            guard let button = tabButtonsByID[id] else { continue }
            tabButtonsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
            tabButtonsByID.removeValue(forKey: id)
        }

        var previousButton: NSView?
        for item in tabView.tabViewItems {
            guard let id = item.identifier as? String else { continue }
            let button: NSButton
            if let existing = tabButtonsByID[id] {
                button = existing
            } else {
                button = makeTabButton(id: id)
                tabButtonsByID[id] = button
                tabButtonsStack.addArrangedSubview(button)
            }

            button.title = item.label
            button.state = (item == tabView.selectedTabViewItem) ? .on : .off

            if let previousButton,
               tabButtonsStack.arrangedSubviews.firstIndex(of: button) ?? 0 <= tabButtonsStack.arrangedSubviews.firstIndex(of: previousButton) ?? -1 {
                tabButtonsStack.removeArrangedSubview(button)
                button.removeFromSuperview()
                if let idx = tabButtonsStack.arrangedSubviews.firstIndex(of: previousButton) {
                    tabButtonsStack.insertArrangedSubview(button, at: idx + 1)
                } else {
                    tabButtonsStack.addArrangedSubview(button)
                }
            }
            previousButton = button
        }
    }

    @objc func selectTabFromButton(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        guard let item = tabView.tabViewItems.first(where: { ($0.identifier as? String) == id }) else { return }
        tabView.selectTabViewItem(item)
        syncTabButtons()
        updateWindowTitle()
        focusCurrentEditor()
        window?.makeFirstResponder(currentSession()?.textView)
    }

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        syncTabButtons()
        updateWindowTitle()
        persistWorkspaceState()
        focusCurrentEditor()
    }

    func makeTabButton(id: String) -> NSButton {
        let button = NSButton(title: "", target: self, action: #selector(selectTabFromButton(_:)))
        button.identifier = NSUserInterfaceItemIdentifier(id)
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.setButtonType(.toggle)
        return button
    }
}

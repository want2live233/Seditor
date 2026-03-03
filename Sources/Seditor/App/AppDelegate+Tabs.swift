import AppKit

private enum CloseTabDecision {
    case save
    case dontSave
    case cancel
}

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
            syncUntitledCounterIfNeeded(from: preferredLabel)
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
            if session.hasPendingUnsavedChanges {
                switch promptCloseDecision(for: item.label) {
                case .save:
                    guard saveSessionBeforeClosing(session) else { return }
                case .dontSave:
                    session.saveWorkItem?.cancel()
                    session.saveWorkItem = nil
                case .cancel:
                    return
                }
            } else {
                session.saveWorkItem?.cancel()
                session.saveWorkItem = nil
                _ = saveAutosave(for: session)
            }

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
            let isSelected = (item == tabView.selectedTabViewItem)
            button.state = isSelected ? .on : .off
            styleTabButton(button, title: item.label, selected: isSelected)

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
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        button.setButtonType(.toggle)
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        return button
    }

    private func styleTabButton(_ button: NSButton, title: String, selected: Bool) {
        let textColor: NSColor = selected ? .controlAccentColor : .labelColor
        let font = NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .regular)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: textColor
            ]
        )
        button.layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.14).cgColor
            : NSColor.clear.cgColor
    }

    private func syncUntitledCounterIfNeeded(from label: String) {
        let prefix = "Untitled "
        guard label.hasPrefix(prefix) else { return }
        let suffix = label.dropFirst(prefix.count)
        guard let number = Int(suffix), number >= untitledCounter else { return }
        untitledCounter = number + 1
    }

    private func promptCloseDecision(for tabLabel: String) -> CloseTabDecision {
        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to \"\(tabLabel)\"?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .dontSave
        default:
            return .cancel
        }
    }

    private func saveSessionBeforeClosing(_ session: EditorSession) -> Bool {
        if session.currentFileURL != nil {
            return saveToCurrentFile(session: session)
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "note.txt"

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        session.currentFileURL = url
        return saveToCurrentFile(session: session)
    }
}

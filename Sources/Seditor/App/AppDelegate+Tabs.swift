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
        workspaceController.createTab(
            autosaveURL: autosaveURL,
            initialContent: initialContent,
            fileURL: fileURL,
            preferredLabel: preferredLabel,
            select: select,
            persist: persist
        )
    }

    func createNewTab(select: Bool) {
        _ = workspaceController.createNewTab(select: select)
    }

    func closeCurrentTab() {
        _ = workspaceController.closeCurrentTab()
    }

    @objc func closeAllTabs() {
        _ = workspaceController.closeAllTabs()
    }

    func updateTabLabel(for session: EditorSession) {
        workspaceController.updateTabLabel(for: session)
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

            let displayTitle = decoratedTabTitle(for: item)
            button.title = displayTitle
            button.setAccessibilityLabel(displayTitle)
            let isSelected = (item == tabView.selectedTabViewItem)
            button.state = isSelected ? .on : .off
            styleTabButton(button, title: displayTitle, selected: isSelected)

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

        updateEmptyStateVisibility()
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
        button.setAccessibilityRole(.radioButton)
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

    private func decoratedTabTitle(for item: NSTabViewItem) -> String {
        guard let session = workspaceController.session(for: item) else {
            return item.label
        }
        if session.hasPendingUnsavedChanges {
            return "● \(item.label)"
        }
        return item.label
    }

    func promptCloseDecision(for tabLabel: String) -> WorkspaceCloseDecision {
        let alert = NSAlert()
        alert.messageText = String(format: L10n.t("prompt.unsaved.title", "Do you want to save the changes made to \"%@\"?"), tabLabel)
        alert.informativeText = L10n.t("prompt.unsaved.message", "Your changes will be lost if you don't save them.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.t("common.save", "Save"))
        alert.addButton(withTitle: L10n.t("common.dontSave", "Don't Save"))
        alert.addButton(withTitle: L10n.t("common.cancel", "Cancel"))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .dontSave
        default:
            return .cancel
        }
    }

    func saveSessionBeforeClosing(_ session: EditorSession) -> Bool {
        if session.currentFileURL != nil {
            return saveToCurrentFile(session: session)
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = L10n.t("file.defaultName", "note.txt")

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        session.currentFileURL = url
        return saveToCurrentFile(session: session)
    }

    func adjustFontSize(by magnification: CGFloat) {
        let stepSize: CGFloat = 0.08
        fontMagnificationAccumulator += magnification

        let steps = Int(fontMagnificationAccumulator / stepSize)
        guard steps != 0 else { return }

        fontMagnificationAccumulator -= CGFloat(steps) * stepSize
        editorFontSize = min(42, max(10, editorFontSize + CGFloat(steps)))
        applyFontSize()
    }
}

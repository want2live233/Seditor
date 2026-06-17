import AppKit

@MainActor
enum WorkspaceCloseDecision {
    case save
    case dontSave
    case cancel
}

@MainActor
final class WorkspaceController {
    let tabView: NSTabView
    let autosaveDirectoryURL: URL

    private(set) var tabItemToSession: [ObjectIdentifier: EditorSession] = [:]
    private(set) var textViewToSession: [ObjectIdentifier: EditorSession] = [:]
    private(set) var clipViewToSession: [ObjectIdentifier: EditorSession] = [:]
    private(set) var untitledCounter = 1

    var configureSession: ((EditorSession) -> Void)?
    var registerSessionObservers: ((EditorSession) -> Void)?
    var unregisterSessionObservers: ((EditorSession) -> Void)?
    var requestRedraw: ((EditorSession, Bool, Bool) -> Void)?
    var syncTabButtons: (() -> Void)?
    var updateWindowTitle: (() -> Void)?
    var persistWorkspaceState: (() -> Void)?
    var focusCurrentEditor: (() -> Void)?
    var saveAutosave: ((EditorSession) -> Bool)?
    var contentForSaving: ((EditorSession) -> String)?
    var readTextAtURL: ((URL) throws -> (content: String, encoding: String.Encoding))?
    var canonicalPathForURL: ((URL) -> String)?
    var promptCloseDecision: ((String) -> WorkspaceCloseDecision)?
    var saveSessionBeforeClosing: ((EditorSession) -> Bool)?

    init(tabView: NSTabView, autosaveDirectoryURL: URL) {
        self.tabView = tabView
        self.autosaveDirectoryURL = autosaveDirectoryURL
    }

    func currentTabItem() -> NSTabViewItem? {
        tabView.selectedTabViewItem
    }

    func currentSession() -> EditorSession? {
        guard let item = currentTabItem() else { return nil }
        return tabItemToSession[ObjectIdentifier(item)]
    }

    func session(for item: NSTabViewItem) -> EditorSession? {
        tabItemToSession[ObjectIdentifier(item)]
    }

    func session(for textView: NSTextView) -> EditorSession? {
        textViewToSession[ObjectIdentifier(textView)]
    }

    func session(for clipView: NSClipView) -> EditorSession? {
        clipViewToSession[ObjectIdentifier(clipView)]
    }

    func allSessions() -> [EditorSession] {
        Array(tabItemToSession.values)
    }

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
        configureSession?(session)

        session.textView.string = initialContent
        session.currentFileURL = fileURL
        session.hasPendingUnsavedChanges = false
        session.gutterView.invalidateCaches()

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
        registerSessionObservers?(session)

        syncTabButtons?()
        updateWindowTitle?()
        requestRedraw?(session, true, true)
        if persist { persistWorkspaceState?() }
        if select {
            DispatchQueue.main.async { [weak self] in
                self?.focusCurrentEditor?()
            }
        }

        return session
    }

    @discardableResult
    func createNewTab(select: Bool) -> EditorSession {
        let autosaveURL = autosaveDirectoryURL.appendingPathComponent("autosave-\(UUID().uuidString).txt")
        return createTab(
            autosaveURL: autosaveURL,
            initialContent: "",
            fileURL: nil,
            preferredLabel: nil,
            select: select
        )
    }

    @discardableResult
    func closeCurrentTab() -> Bool {
        guard let item = currentTabItem() else { return false }
        guard closeTabItem(item, promptToSave: true) else { return false }
        finalizeAfterClosingTabs()
        return true
    }

    @discardableResult
    func closeAllTabs() -> Bool {
        let items = tabView.tabViewItems
        guard !items.isEmpty else { return false }

        var closedAny = false
        for item in items {
            tabView.selectTabViewItem(item)
            guard closeTabItem(item, promptToSave: true) else { break }
            closedAny = true
        }

        if closedAny {
            finalizeAfterClosingTabs()
        }
        return closedAny
    }

    func updateTabLabel(for session: EditorSession) {
        guard let item = tabView.tabViewItems.first(where: { tabItemToSession[ObjectIdentifier($0)] === session }) else { return }
        if let fileURL = session.currentFileURL {
            item.label = fileURL.lastPathComponent
        } else if item.label.isEmpty {
            item.label = "Untitled"
        }
        syncTabButtons?()
        persistWorkspaceState?()
    }

    @discardableResult
    func saveToCurrentFile(session: EditorSession) -> Bool {
        guard let url = session.currentFileURL else { return false }
        do {
            let content = contentForSaving?(session) ?? session.textView.string
            try content.write(to: url, atomically: true, encoding: session.currentFileEncoding)
            session.hasPendingUnsavedChanges = false
            _ = saveAutosave?(session)
            updateTabLabel(for: session)
            updateWindowTitle?()
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    @discardableResult
    func openDocuments(at urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return true }
        guard let readTextAtURL, let canonicalPathForURL else { return false }

        var openedAny = false
        var seenCanonicalPaths = Set<String>()

        for url in urls {
            let canonical = canonicalPathForURL(url)
            if !seenCanonicalPaths.insert(canonical).inserted { continue }

            do {
                let loaded = try readTextAtURL(url)
                let existingSession = tabItemToSession.values.first {
                    guard let currentFileURL = $0.currentFileURL else { return false }
                    return canonicalPathForURL(currentFileURL) == canonical
                }
                let reusableBlankSession: EditorSession? = {
                    guard tabView.numberOfTabViewItems == 1, let only = currentSession() else { return nil }
                    return (only.currentFileURL == nil && only.textView.string.isEmpty) ? only : nil
                }()

                let session: EditorSession
                if let existingSession {
                    session = existingSession
                } else if let reusableBlankSession {
                    session = reusableBlankSession
                } else {
                    session = createNewTab(select: true)
                }

                session.saveWorkItem?.cancel()
                session.saveWorkItem = nil
                session.textView.undoManager?.disableUndoRegistration()
                session.textView.string = loaded.content
                session.textView.undoManager?.enableUndoRegistration()
                session.textView.undoManager?.removeAllActions()
                session.gutterView.invalidateCaches()
                session.currentFileURL = URL(fileURLWithPath: canonical)
                session.currentFileEncoding = loaded.encoding
                session.hasPendingUnsavedChanges = false

                updateTabLabel(for: session)
                requestRedraw?(session, true, true)

                if let item = tabView.tabViewItems.first(where: { tabItemToSession[ObjectIdentifier($0)] === session }) {
                    tabView.selectTabViewItem(item)
                }

                openedAny = true
            } catch {
                NSSound.beep()
            }
        }

        if openedAny {
            updateWindowTitle?()
            focusCurrentEditor?()
        }

        return openedAny
    }

    private func closeTabItem(_ item: NSTabViewItem, promptToSave: Bool) -> Bool {
        let key = ObjectIdentifier(item)
        guard let session = tabItemToSession[key] else {
            tabView.removeTabViewItem(item)
            return true
        }

        if promptToSave && session.hasPendingUnsavedChanges {
            switch promptCloseDecision?(item.label) ?? .cancel {
            case .save:
                guard saveSessionBeforeClosing?(session) ?? false else { return false }
            case .dontSave:
                break
            case .cancel:
                return false
            }
        }

        session.saveWorkItem?.cancel()
        session.saveWorkItem = nil
        unregisterSessionObservers?(session)
        textViewToSession.removeValue(forKey: ObjectIdentifier(session.textView))
        clipViewToSession.removeValue(forKey: ObjectIdentifier(session.editorScrollView.contentView))
        tabItemToSession.removeValue(forKey: key)
        tabView.removeTabViewItem(item)
        discardAutosave(for: session)
        return true
    }

    private func discardAutosave(for session: EditorSession) {
        try? FileManager.default.removeItem(at: session.autosaveURL)
    }

    private func finalizeAfterClosingTabs() {
        syncTabButtons?()
        updateWindowTitle?()
        persistWorkspaceState?()
        focusCurrentEditor?()
    }

    private func syncUntitledCounterIfNeeded(from label: String) {
        let prefix = "Untitled "
        guard label.hasPrefix(prefix) else { return }
        let suffix = label.dropFirst(prefix.count)
        guard let number = Int(suffix), number >= untitledCounter else { return }
        untitledCounter = number + 1
    }
}

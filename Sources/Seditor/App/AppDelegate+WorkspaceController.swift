import AppKit

@MainActor
extension AppDelegate {
    func configureWorkspaceControllerCallbacks() {
        workspaceController.configureSession = { [weak self] session in
            guard let self else { return }
            session.textView.delegate = self
            session.textView.onMagnify = { [weak self] magnification in
                self?.adjustFontSize(by: magnification)
            }
            session.currentFileEncoding = self.defaultFileEncoding
            session.preferredLineEnding = self.defaultLineEnding
            self.applyTheme(to: session)
            self.applyFontSize(to: session)
        }

        workspaceController.registerSessionObservers = { [weak self] session in
            guard let self else { return }
            let clip = session.editorScrollView.contentView
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(editorDidScroll(_:)),
                name: NSView.boundsDidChangeNotification,
                object: clip
            )
        }

        workspaceController.unregisterSessionObservers = { [weak self] session in
            guard let self else { return }
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: session.editorScrollView.contentView
            )
        }

        workspaceController.requestRedraw = { [weak self] session, gutter, editor in
            self?.requestRedraw(for: session, gutter: gutter, editor: editor)
        }
        workspaceController.syncTabButtons = { [weak self] in
            self?.syncTabButtons()
        }
        workspaceController.updateWindowTitle = { [weak self] in
            self?.updateWindowTitle()
        }
        workspaceController.persistWorkspaceState = { [weak self] in
            self?.persistWorkspaceState()
        }
        workspaceController.focusCurrentEditor = { [weak self] in
            self?.focusCurrentEditor()
        }
        workspaceController.saveAutosave = { [weak self] session in
            self?.saveAutosave(for: session) ?? false
        }
        workspaceController.contentForSaving = { [weak self] session in
            self?.textForSaving(from: session) ?? session.textView.string
        }
        workspaceController.readTextAtURL = { [weak self] url in
            guard let self else { throw CocoaError(.fileNoSuchFile) }
            return try self.readText(at: url)
        }
        workspaceController.canonicalPathForURL = { [weak self] url in
            self?.canonicalPath(for: url) ?? url.resolvingSymlinksInPath().standardizedFileURL.path
        }
        workspaceController.promptCloseDecision = { [weak self] tabLabel in
            self?.promptCloseDecision(for: tabLabel) ?? .cancel
        }
        workspaceController.saveSessionBeforeClosing = { [weak self] session in
            self?.saveSessionBeforeClosing(session) ?? false
        }
    }
}

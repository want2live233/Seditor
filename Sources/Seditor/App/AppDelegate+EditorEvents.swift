import AppKit

@MainActor
extension AppDelegate {
    func textDidChange(_ notification: Notification) {
        guard
            let textView = notification.object as? NSTextView,
            let session = workspaceController.session(for: textView)
        else { return }

        session.gutterView.invalidateCaches()
        requestRedraw(for: session, gutter: true, editor: false)
        let wasPendingUnsavedChanges = session.hasPendingUnsavedChanges
        session.hasPendingUnsavedChanges = true
        if !wasPendingUnsavedChanges {
            syncTabButtons()
            persistWorkspaceState()
        }
        updateStatusBar(for: session)
        scheduleAutosave(for: session)
    }

    func scheduleAutosave(for session: EditorSession) {
        session.saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self, weak session] in
            guard let self, let session else { return }
            session.saveWorkItem = nil
            _ = self.saveAutosave(for: session)
        }
        session.saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }

    @discardableResult
    func saveAutosave(for session: EditorSession) -> Bool {
        do {
            try session.textView.string.write(to: session.autosaveURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    @objc func editorDidScroll(_ notification: Notification) {
        guard let clip = notification.object as? NSClipView,
              let session = workspaceController.session(for: clip)
        else { return }
        requestRedraw(for: session, gutter: true, editor: true)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard
            let textView = notification.object as? NSTextView,
            let session = workspaceController.session(for: textView)
        else { return }
        requestRedraw(for: session, gutter: true, editor: true)
        updateStatusBar(for: session)
    }
}

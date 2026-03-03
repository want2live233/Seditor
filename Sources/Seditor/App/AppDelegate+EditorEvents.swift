import AppKit

@MainActor
extension AppDelegate {
    func textDidChange(_ notification: Notification) {
        guard
            let textView = notification.object as? NSTextView,
            let session = textViewToSession[ObjectIdentifier(textView)]
        else { return }

        session.gutterView.invalidateCaches()
        requestRedraw(for: session, gutter: true, editor: false)
        session.hasPendingUnsavedChanges = true
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
        if let fileURL = session.currentFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try session.textView.string.write(to: fileURL, atomically: true, encoding: session.currentFileEncoding)
                session.hasPendingUnsavedChanges = false
                return true
            } catch {
                // Fall back to autosave file to avoid data loss.
            }
        }

        do {
            try session.textView.string.write(to: session.autosaveURL, atomically: true, encoding: .utf8)
            session.hasPendingUnsavedChanges = false
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    @objc func editorDidScroll(_ notification: Notification) {
        guard let clip = notification.object as? NSClipView,
              let session = clipViewToSession[ObjectIdentifier(clip)]
        else { return }
        requestRedraw(for: session, gutter: true, editor: true)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard
            let textView = notification.object as? NSTextView,
            let session = textViewToSession[ObjectIdentifier(textView)]
        else { return }
        requestRedraw(for: session, gutter: true, editor: true)
    }
}

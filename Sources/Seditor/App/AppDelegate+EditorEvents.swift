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
        scheduleAutosave(for: session)
    }

    func scheduleAutosave(for session: EditorSession) {
        session.saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.saveAutosave(for: session)
        }
        session.saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }

    func saveAutosave(for session: EditorSession) {
        do {
            try session.textView.string.write(to: session.autosaveURL, atomically: true, encoding: .utf8)
        } catch {
            NSSound.beep()
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

import AppKit
import UniformTypeIdentifiers

@MainActor
extension AppDelegate {
    func saveToCurrentFile(session: EditorSession) {
        guard let url = session.currentFileURL else { return }
        do {
            try session.textView.string.write(to: url, atomically: true, encoding: .utf8)
            updateTabLabel(for: session)
            updateWindowTitle()
        } catch {
            NSSound.beep()
        }
    }

    @objc func openDocument() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            guard let self else { return }

            for url in panel.urls {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    self.createNewTab(select: true)
                    guard let session = self.currentSession() else { continue }
                    session.textView.string = content
                    session.gutterView.invalidateCaches()
                    session.currentFileURL = url
                    self.updateTabLabel(for: session)
                    self.requestRedraw(for: session, gutter: true, editor: true)
                } catch {
                    NSSound.beep()
                }
            }

            self.updateWindowTitle()
            self.focusCurrentEditor()
        }
    }

    @objc func saveDocument() {
        guard let session = currentSession() else { return }
        if session.currentFileURL == nil {
            saveDocumentAs()
            return
        }
        saveToCurrentFile(session: session)
    }

    @objc func saveDocumentAs() {
        guard let window, let session = currentSession() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = session.currentFileURL?.lastPathComponent ?? "note.txt"

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let self else { return }
            session.currentFileURL = url
            self.saveToCurrentFile(session: session)
        }
    }
}

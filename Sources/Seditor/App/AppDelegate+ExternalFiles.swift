import AppKit

@MainActor
extension AppDelegate {
    func checkForExternalModificationIfNeeded(for session: EditorSession) {
        guard let fileURL = session.currentFileURL else { return }
        guard let currentDate = fileModificationDate(for: fileURL) else { return }

        guard let knownDate = session.knownFileModificationDate else {
            session.knownFileModificationDate = currentDate
            return
        }

        if currentDate <= knownDate {
            return
        }

        if let ignoredDate = session.ignoredExternalModificationDate,
           abs(ignoredDate.timeIntervalSince1970 - currentDate.timeIntervalSince1970) < 0.5 {
            return
        }

        let alert = NSAlert()
        alert.messageText = L10n.t("external.modified.title", "File Modified Externally")
        alert.informativeText = String(
            format: L10n.t("external.modified.message", "\"%@\" changed on disk. Reload from disk?"),
            fileURL.lastPathComponent
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.t("external.reload", "Reload"))
        alert.addButton(withTitle: L10n.t("external.keepCurrent", "Keep Current"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            do {
                let loaded = try readText(at: fileURL)
                session.saveWorkItem?.cancel()
                session.saveWorkItem = nil
                session.textView.undoManager?.disableUndoRegistration()
                session.textView.string = loaded.content
                session.textView.undoManager?.enableUndoRegistration()
                session.textView.undoManager?.removeAllActions()
                session.currentFileEncoding = loaded.encoding
                session.preferredLineEnding = detectPreferredLineEnding(in: loaded.content)
                session.hasPendingUnsavedChanges = false
                session.ignoredExternalModificationDate = nil
                session.knownFileModificationDate = currentDate
                session.gutterView.invalidateCaches()
                updateTabLabel(for: session)
                requestRedraw(for: session, gutter: true, editor: true)
                updateStatusBar(for: session)
            } catch {
                NSSound.beep()
            }
        } else {
            session.ignoredExternalModificationDate = currentDate
        }
    }

    func updateKnownModificationDate(for session: EditorSession, resetIgnored: Bool = true) {
        guard let fileURL = session.currentFileURL else {
            session.knownFileModificationDate = nil
            if resetIgnored {
                session.ignoredExternalModificationDate = nil
            }
            return
        }

        session.knownFileModificationDate = fileModificationDate(for: fileURL)
        if resetIgnored {
            session.ignoredExternalModificationDate = nil
        }
    }

    func refreshKnownModificationDatesForOpenFiles() {
        for session in workspaceController.allSessions() {
            guard session.currentFileURL != nil else { continue }
            updateKnownModificationDate(for: session)
        }
    }

    private func fileModificationDate(for url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }
}

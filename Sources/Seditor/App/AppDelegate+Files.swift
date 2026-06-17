import AppKit
import CoreFoundation
import UniformTypeIdentifiers

@MainActor
extension AppDelegate {
    private static let gb2312CFEncoding = CFStringEncoding(0x0630)
    private static let gbkCFEncoding = CFStringEncoding(0x0631)
    private static let gb18030CFEncoding = CFStringEncoding(0x0632)

    private var gb2312Encoding: String.Encoding {
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(Self.gb2312CFEncoding))
    }

    private var gbkEncoding: String.Encoding {
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(Self.gbkCFEncoding))
    }

    private var gb18030Encoding: String.Encoding {
        .init(rawValue: CFStringConvertEncodingToNSStringEncoding(Self.gb18030CFEncoding))
    }

    private var supportedOpenEncodings: [String.Encoding] {
        [.utf8, gb18030Encoding, gbkEncoding, gb2312Encoding]
    }

    func readText(at url: URL) throws -> (content: String, encoding: String.Encoding) {
        let data = try Data(contentsOf: url)
        for encoding in supportedOpenEncodings {
            if let content = String(data: data, encoding: encoding) {
                return (content, encoding)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    @discardableResult
    func openDocuments(at urls: [URL]) -> Bool {
        let opened = workspaceController.openDocuments(at: urls)
        if opened {
            refreshKnownModificationDatesForOpenFiles()
            refreshPreferredLineEndingsForOpenFiles()
        }
        return opened
    }

    @discardableResult
    func saveToCurrentFile(session: EditorSession) -> Bool {
        let saved = workspaceController.saveToCurrentFile(session: session)
        if saved {
            updateKnownModificationDate(for: session)
            updateStatusBar(for: session)
        }
        return saved
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
            _ = self.openDocuments(at: panel.urls)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openDocuments(at: [URL(fileURLWithPath: filename)])
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        let opened = openDocuments(at: urls)
        application.reply(toOpenOrPrint: opened ? .success : .failure)
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
        panel.nameFieldStringValue = session.currentFileURL?.lastPathComponent ?? L10n.t("file.defaultName", "note.txt")

        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let self else { return }
            session.currentFileURL = url
            self.saveToCurrentFile(session: session)
        }
    }
}

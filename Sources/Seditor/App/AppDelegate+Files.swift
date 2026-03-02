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

    private func readText(at url: URL) throws -> (content: String, encoding: String.Encoding) {
        let data = try Data(contentsOf: url)
        for encoding in supportedOpenEncodings {
            if let content = String(data: data, encoding: encoding) {
                return (content, encoding)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }

    func saveToCurrentFile(session: EditorSession) {
        guard let url = session.currentFileURL else { return }
        do {
            try session.textView.string.write(to: url, atomically: true, encoding: session.currentFileEncoding)
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
                    let loaded = try self.readText(at: url)
                    self.createNewTab(select: true)
                    guard let session = self.currentSession() else { continue }
                    session.textView.string = loaded.content
                    session.gutterView.invalidateCaches()
                    session.currentFileURL = url
                    session.currentFileEncoding = loaded.encoding
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

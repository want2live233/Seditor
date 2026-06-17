import Foundation

struct PersistedWorkspaceTab: Codable {
    let autosaveFileName: String
    let currentFilePath: String?
    let label: String?
    let hadPendingUnsavedChanges: Bool?
}

struct PersistedWorkspaceState: Codable {
    let tabs: [PersistedWorkspaceTab]
    let selectedIndex: Int
}

struct RestoredTabPayload {
    let autosaveURL: URL
    let fileURL: URL?
    let content: String
    let encoding: String.Encoding
}

final class WorkspacePersistenceService {
    let autosaveDirectoryURL: URL
    let sessionStateURL: URL

    init(autosaveDirectoryURL: URL, sessionStateURL: URL) {
        self.autosaveDirectoryURL = autosaveDirectoryURL
        self.sessionStateURL = sessionStateURL
    }

    func loadWorkspaceState() -> PersistedWorkspaceState? {
        guard let data = try? Data(contentsOf: sessionStateURL) else { return nil }
        return try? JSONDecoder().decode(PersistedWorkspaceState.self, from: data)
    }

    func saveWorkspaceState(_ state: PersistedWorkspaceState) {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: sessionStateURL, options: .atomic)
        } catch {
            // Non-fatal: autosave content still exists per tab.
        }
    }

    func makeRestoredTabPayload(
        for tab: PersistedWorkspaceTab,
        readTextAtURL: (URL) throws -> (content: String, encoding: String.Encoding)
    ) -> RestoredTabPayload {
        let autosaveURL = autosaveDirectoryURL.appendingPathComponent(tab.autosaveFileName)
        let fileURL = tab.currentFilePath.map { URL(fileURLWithPath: $0) }

        let shouldPreferAutosave = tab.hadPendingUnsavedChanges ?? false
        let restoredContent: String
        let restoredEncoding: String.Encoding

        if shouldPreferAutosave, let autosaved = try? String(contentsOf: autosaveURL, encoding: .utf8) {
            restoredContent = autosaved
            restoredEncoding = .utf8
        } else if let fileURL, let loaded = try? readTextAtURL(fileURL) {
            restoredContent = loaded.content
            restoredEncoding = loaded.encoding
        } else {
            restoredContent = (try? String(contentsOf: autosaveURL, encoding: .utf8)) ?? ""
            restoredEncoding = .utf8
        }

        return RestoredTabPayload(
            autosaveURL: autosaveURL,
            fileURL: fileURL,
            content: restoredContent,
            encoding: restoredEncoding
        )
    }
}

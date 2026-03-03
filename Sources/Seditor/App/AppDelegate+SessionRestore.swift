import Foundation

private struct PersistedTab: Codable {
    let autosaveFileName: String
    let currentFilePath: String?
    let label: String?
}

private struct PersistedWorkspace: Codable {
    let tabs: [PersistedTab]
    let selectedIndex: Int
}

@MainActor
extension AppDelegate {
    func restoreTabsOrCreateDefault() {
        // Files can be opened by the system before app launch finishes.
        // Merge restored tabs with already opened tabs instead of dropping either side.
        let hadTabsBeforeRestore = tabView.numberOfTabViewItems > 0

        guard let workspace = loadPersistedWorkspace(), !workspace.tabs.isEmpty else {
            if !hadTabsBeforeRestore {
                createNewTab(select: true)
            }
            persistWorkspaceState()
            return
        }

        var existingAutosaveNames = Set<String>()
        var existingCanonicalPaths = Set<String>()
        for item in tabView.tabViewItems {
            guard let session = tabItemToSession[ObjectIdentifier(item)] else { continue }
            existingAutosaveNames.insert(session.autosaveURL.lastPathComponent)
            if let currentFileURL = session.currentFileURL {
                existingCanonicalPaths.insert(canonicalPathForRestore(currentFileURL))
            }
        }

        for tab in workspace.tabs {
            let autosaveURL = autosaveDirectoryURL.appendingPathComponent(tab.autosaveFileName)
            let fileURL = tab.currentFilePath.map { URL(fileURLWithPath: $0) }

            if existingAutosaveNames.contains(tab.autosaveFileName) {
                continue
            }
            if let fileURL {
                let canonical = canonicalPathForRestore(fileURL)
                if existingCanonicalPaths.contains(canonical) {
                    continue
                }
            }

            let restoredContent: String
            let restoredEncoding: String.Encoding
            if let fileURL, let loaded = try? readText(at: fileURL) {
                restoredContent = loaded.content
                restoredEncoding = loaded.encoding
            } else {
                restoredContent = (try? String(contentsOf: autosaveURL, encoding: .utf8)) ?? ""
                restoredEncoding = .utf8
            }

            let session = createTab(
                autosaveURL: autosaveURL,
                initialContent: restoredContent,
                fileURL: fileURL,
                preferredLabel: tab.label,
                select: false,
                persist: false
            )
            session.currentFileEncoding = restoredEncoding
            existingAutosaveNames.insert(tab.autosaveFileName)
            if let fileURL {
                existingCanonicalPaths.insert(canonicalPathForRestore(fileURL))
            }
        }

        if !hadTabsBeforeRestore {
            let idx = min(max(0, workspace.selectedIndex), max(0, tabView.numberOfTabViewItems - 1))
            tabView.selectTabViewItem(at: idx)
        }
        syncTabButtons()
        updateWindowTitle()
        persistWorkspaceState()
    }

    func persistWorkspaceState(force: Bool = false) {
        guard force || hasCompletedInitialWorkspaceRestore else { return }
        var tabs: [PersistedTab] = []
        tabs.reserveCapacity(tabView.numberOfTabViewItems)

        for item in tabView.tabViewItems {
            guard let session = tabItemToSession[ObjectIdentifier(item)] else { continue }
            tabs.append(
                PersistedTab(
                    autosaveFileName: session.autosaveURL.lastPathComponent,
                    currentFilePath: session.currentFileURL?.path,
                    label: item.label
                )
            )
        }

        let selectedIndex = tabView.selectedTabViewItem.map { tabView.indexOfTabViewItem($0) } ?? 0
        let workspace = PersistedWorkspace(tabs: tabs, selectedIndex: max(0, selectedIndex))

        do {
            let data = try JSONEncoder().encode(workspace)
            try data.write(to: sessionStateURL, options: .atomic)
        } catch {
            // Non-fatal: autosave content still exists per tab.
        }
    }

    private func loadPersistedWorkspace() -> PersistedWorkspace? {
        guard let data = try? Data(contentsOf: sessionStateURL) else { return nil }
        return try? JSONDecoder().decode(PersistedWorkspace.self, from: data)
    }

    private func canonicalPathForRestore(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

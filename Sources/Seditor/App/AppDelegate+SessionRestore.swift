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
        guard let workspace = loadPersistedWorkspace(), !workspace.tabs.isEmpty else {
            createNewTab(select: true)
            persistWorkspaceState()
            return
        }

        for tab in workspace.tabs {
            let autosaveURL = autosaveDirectoryURL.appendingPathComponent(tab.autosaveFileName)
            let content = (try? String(contentsOf: autosaveURL, encoding: .utf8)) ?? ""
            let fileURL = tab.currentFilePath.map { URL(fileURLWithPath: $0) }
            _ = createTab(
                autosaveURL: autosaveURL,
                initialContent: content,
                fileURL: fileURL,
                preferredLabel: tab.label,
                select: false,
                persist: false
            )
        }

        let idx = min(max(0, workspace.selectedIndex), max(0, tabView.numberOfTabViewItems - 1))
        tabView.selectTabViewItem(at: idx)
        syncTabButtons()
        updateWindowTitle()
        persistWorkspaceState()
    }

    func persistWorkspaceState() {
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
}


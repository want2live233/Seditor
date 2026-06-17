import Foundation

@MainActor
extension AppDelegate {
    func restoreTabsOrCreateDefault() {
        // Files can be opened by the system before app launch finishes.
        // Merge restored tabs with already opened tabs instead of dropping either side.
        let hadTabsBeforeRestore = tabView.numberOfTabViewItems > 0

        guard let workspace = workspacePersistenceService.loadWorkspaceState(), !workspace.tabs.isEmpty else {
            syncTabButtons()
            persistWorkspaceState()
            return
        }

        var existingAutosaveNames = Set<String>()
        var existingCanonicalPaths = Set<String>()
        for item in tabView.tabViewItems {
            guard let session = workspaceController.session(for: item) else { continue }
            existingAutosaveNames.insert(session.autosaveURL.lastPathComponent)
            if let currentFileURL = session.currentFileURL {
                existingCanonicalPaths.insert(canonicalPathForRestore(currentFileURL))
            }
        }

        for tab in workspace.tabs {
            if existingAutosaveNames.contains(tab.autosaveFileName) {
                continue
            }

            let restored = workspacePersistenceService.makeRestoredTabPayload(for: tab) { url in
                try readText(at: url)
            }

            if let fileURL = restored.fileURL {
                let canonical = canonicalPathForRestore(fileURL)
                if existingCanonicalPaths.contains(canonical) {
                    continue
                }
            }

            let session = createTab(
                autosaveURL: restored.autosaveURL,
                initialContent: restored.content,
                fileURL: restored.fileURL,
                preferredLabel: tab.label,
                select: false,
                persist: false
            )
            session.currentFileEncoding = restored.encoding
            session.hasPendingUnsavedChanges = tab.hadPendingUnsavedChanges ?? false
            session.preferredLineEnding = detectPreferredLineEnding(in: restored.content)
            updateKnownModificationDate(for: session)

            existingAutosaveNames.insert(tab.autosaveFileName)
            if let fileURL = restored.fileURL {
                existingCanonicalPaths.insert(canonicalPathForRestore(fileURL))
            }
        }

        if !hadTabsBeforeRestore, tabView.numberOfTabViewItems > 0 {
            let idx = min(max(0, workspace.selectedIndex), max(0, tabView.numberOfTabViewItems - 1))
            tabView.selectTabViewItem(at: idx)
        }
        syncTabButtons()
        updateWindowTitle()
        persistWorkspaceState()
    }

    func persistWorkspaceState(force: Bool = false) {
        guard force || hasCompletedInitialWorkspaceRestore else { return }
        var tabs: [PersistedWorkspaceTab] = []
        tabs.reserveCapacity(tabView.numberOfTabViewItems)

        for item in tabView.tabViewItems {
            guard let session = workspaceController.session(for: item) else { continue }
            tabs.append(
                PersistedWorkspaceTab(
                    autosaveFileName: session.autosaveURL.lastPathComponent,
                    currentFilePath: session.currentFileURL?.path,
                    label: item.label,
                    hadPendingUnsavedChanges: session.hasPendingUnsavedChanges
                )
            )
        }

        let selectedIndex = tabView.selectedTabViewItem.map { tabView.indexOfTabViewItem($0) } ?? 0
        let state = PersistedWorkspaceState(tabs: tabs, selectedIndex: max(0, selectedIndex))
        workspacePersistenceService.saveWorkspaceState(state)
    }

    private func canonicalPathForRestore(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

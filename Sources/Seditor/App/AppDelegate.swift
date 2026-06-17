import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSWindowDelegate, NSTabViewDelegate {
    let gutterWidth: CGFloat = 56
    let tabBarHeight: CGFloat = 34
    let statusBarHeight: CGFloat = 34

    var window: NSWindow?
    let workspaceView = NSView(frame: .zero)
    let tabBarView = NSView(frame: .zero)
    let statusBarView = NSView(frame: .zero)
    let statusBarStack = NSStackView(frame: .zero)
    let cursorPositionLabel = NSTextField(labelWithString: L10n.t("status.cursor.none", "Ln -, Col -"))
    let encodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let lineEndingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let tabButtonsStack = NSStackView(frame: .zero)
    let newTabButton = NSButton(frame: .zero)
    let tabView = NSTabView(frame: .zero)
    let emptyStateView = NSStackView(frame: .zero)
    let emptyStateTitleLabel = NSTextField(labelWithString: L10n.t("empty.title", "No file is open"))
    let emptyStateHintLabel = NSTextField(labelWithString: L10n.t("empty.hint", "Press Command+O to open a file, or Command+T to create a new tab."))
    let emptyStateButtons = NSStackView(frame: .zero)
    let emptyStateOpenButton = NSButton(frame: .zero)
    let emptyStateNewButton = NSButton(frame: .zero)
    var helpWindow: NSWindow?
    var settingsWindow: NSWindow?
    let settingsThemePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let settingsFontStepper = NSStepper(frame: .zero)
    let settingsFontField = NSTextField(string: "")
    let settingsEncodingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let settingsLineEndingPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    var tabButtonsByID: [String: NSButton] = [:]
    var editorFontSize: CGFloat = 14
    var editorTheme: EditorTheme = .system
    var defaultFileEncoding: String.Encoding = .utf8
    var defaultLineEnding: LineEndingStyle = .lf
    let redrawInterval: TimeInterval = 1.0 / 60.0
    var hasCompletedInitialWorkspaceRestore = false
    var fontMagnificationAccumulator: CGFloat = 0
    var isUpdatingStatusBarControls = false

    lazy var autosaveDirectoryURL: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Seditor", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    lazy var sessionStateURL: URL = autosaveDirectoryURL.appendingPathComponent("sessions.json")
    lazy var workspaceController = WorkspaceController(tabView: tabView, autosaveDirectoryURL: autosaveDirectoryURL)
    lazy var workspacePersistenceService = WorkspacePersistenceService(
        autosaveDirectoryURL: autosaveDirectoryURL,
        sessionStateURL: sessionStateURL
    )
    lazy var userDefaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPreferences()
        setupMenu()
        configureAppIcon()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        setupTabView(in: window)
        configureWorkspaceControllerCallbacks()
        restoreTabsOrCreateDefault()
        hasCompletedInitialWorkspaceRestore = true
        persistWorkspaceState()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async { [weak self] in
            self?.focusCurrentEditor()
        }
    }

    func setupTabView(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        workspaceView.translatesAutoresizingMaskIntoConstraints = false
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        statusBarView.translatesAutoresizingMaskIntoConstraints = false
        statusBarStack.translatesAutoresizingMaskIntoConstraints = false
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        newTabButton.translatesAutoresizingMaskIntoConstraints = false

        tabView.tabViewType = .noTabsNoBorder
        tabView.delegate = self
        tabButtonsStack.orientation = .horizontal
        tabButtonsStack.spacing = 6
        tabButtonsStack.alignment = .centerY
        tabButtonsStack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        tabButtonsStack.setContentHuggingPriority(.required, for: .vertical)
        tabButtonsStack.setContentCompressionResistancePriority(.required, for: .vertical)
        newTabButton.title = "+"
        newTabButton.bezelStyle = .texturedRounded
        newTabButton.isBordered = true
        newTabButton.target = self
        newTabButton.action = #selector(newTab)
        newTabButton.setAccessibilityLabel(L10n.t("a11y.newTab", "New Tab"))

        contentView.addSubview(workspaceView)
        workspaceView.addSubview(tabBarView)
        workspaceView.addSubview(statusBarView)
        workspaceView.addSubview(tabView)
        workspaceView.addSubview(emptyStateView)
        tabBarView.addSubview(tabButtonsStack)
        tabBarView.addSubview(newTabButton)
        statusBarView.addSubview(statusBarStack)

        NSLayoutConstraint.activate([
            workspaceView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            workspaceView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            workspaceView.topAnchor.constraint(equalTo: contentView.topAnchor),
            workspaceView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            tabBarView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
            tabBarView.topAnchor.constraint(equalTo: workspaceView.topAnchor),
            tabBarView.heightAnchor.constraint(equalToConstant: tabBarHeight),

            statusBarView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            statusBarView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: workspaceView.bottomAnchor),
            statusBarView.heightAnchor.constraint(equalToConstant: statusBarHeight),

            tabButtonsStack.leadingAnchor.constraint(equalTo: tabBarView.leadingAnchor, constant: gutterWidth + 8),
            tabButtonsStack.trailingAnchor.constraint(lessThanOrEqualTo: newTabButton.leadingAnchor, constant: -8),
            tabButtonsStack.centerYAnchor.constraint(equalTo: tabBarView.centerYAnchor),

            newTabButton.trailingAnchor.constraint(equalTo: tabBarView.trailingAnchor, constant: -8),
            newTabButton.centerYAnchor.constraint(equalTo: tabBarView.centerYAnchor),

            tabView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            tabView.bottomAnchor.constraint(equalTo: statusBarView.topAnchor),

            statusBarStack.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor, constant: 10),
            statusBarStack.trailingAnchor.constraint(equalTo: statusBarView.trailingAnchor, constant: -10),
            statusBarStack.centerYAnchor.constraint(equalTo: statusBarView.centerYAnchor),

            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: workspaceView.leadingAnchor, constant: 20),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: workspaceView.trailingAnchor, constant: -20),
            emptyStateView.centerXAnchor.constraint(equalTo: workspaceView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: tabView.centerYAnchor)
        ])

        tabBarView.wantsLayer = true
        tabBarView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        tabBarView.layer?.zPosition = 100
        tabBarView.layer?.borderWidth = 1
        tabBarView.layer?.borderColor = NSColor.separatorColor.cgColor
        statusBarView.wantsLayer = true

        configureEmptyStateView()
        configureStatusBarView()
        updateEmptyStateVisibility()
    }

    func currentTabItem() -> NSTabViewItem? {
        workspaceController.currentTabItem()
    }

    func currentSession() -> EditorSession? {
        workspaceController.currentSession()
    }

    func updateWindowTitle() {
        window?.title = ""
    }

    func focusCurrentEditor() {
        guard let window else { return }
        guard let session = currentSession() else {
            if !emptyStateView.isHidden {
                window.makeFirstResponder(emptyStateOpenButton)
            } else {
                window.makeFirstResponder(nil)
            }
            updateStatusBarForCurrentSession()
            return
        }
        window.makeFirstResponder(session.textView)
        requestRedraw(for: session, gutter: true, editor: true)
        updateStatusBar(for: session)
        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.currentSession() else { return }
            self.window?.makeFirstResponder(session.textView)
            self.updateStatusBar(for: session)
            self.checkForExternalModificationIfNeeded(for: session)
        }
    }

    func requestRedraw(for session: EditorSession, gutter: Bool, editor: Bool) {
        session.pendingGutterRedraw = session.pendingGutterRedraw || gutter
        session.pendingEditorRedraw = session.pendingEditorRedraw || editor
        guard session.redrawWorkItem == nil else { return }

        let item = DispatchWorkItem {
            session.redrawWorkItem = nil
            if session.pendingGutterRedraw {
                session.gutterView.needsDisplay = true
            }
            if session.pendingEditorRedraw {
                session.textView.needsDisplay = true
            }
            session.pendingGutterRedraw = false
            session.pendingEditorRedraw = false
        }

        session.redrawWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + redrawInterval, execute: item)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        focusCurrentEditor()
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        if closingWindow == helpWindow {
            helpWindow = nil
        }
        if closingWindow == settingsWindow {
            settingsWindow = nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for item in tabView.tabViewItems {
            guard let session = workspaceController.session(for: item), session.hasPendingUnsavedChanges else { continue }
            tabView.selectTabViewItem(item)
            syncTabButtons()
            focusCurrentEditor()

            switch promptCloseDecision(for: item.label) {
            case .save:
                guard saveSessionBeforeClosing(session) else {
                    return .terminateCancel
                }
            case .dontSave:
                session.saveWorkItem?.cancel()
                session.saveWorkItem = nil
                session.hasPendingUnsavedChanges = false
                try? FileManager.default.removeItem(at: session.autosaveURL)
            case .cancel:
                return .terminateCancel
            }
        }
        syncTabButtons()
        persistWorkspaceState()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        for session in workspaceController.allSessions() {
            session.saveWorkItem?.cancel()
            if session.hasPendingUnsavedChanges {
                saveAutosave(for: session)
            }
        }
        persistWorkspaceState(force: true)
    }

    func configureEmptyStateView() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.orientation = .vertical
        emptyStateView.alignment = .centerX
        emptyStateView.spacing = 12

        emptyStateTitleLabel.font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        emptyStateTitleLabel.textColor = .secondaryLabelColor

        emptyStateHintLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        emptyStateHintLabel.textColor = .tertiaryLabelColor
        emptyStateHintLabel.alignment = .center
        emptyStateHintLabel.maximumNumberOfLines = 0
        emptyStateHintLabel.lineBreakMode = .byWordWrapping

        emptyStateOpenButton.title = L10n.t("empty.open", "Open File...")
        emptyStateOpenButton.bezelStyle = .rounded
        emptyStateOpenButton.target = self
        emptyStateOpenButton.action = #selector(openDocument)
        emptyStateOpenButton.setAccessibilityLabel(L10n.t("empty.open", "Open File..."))
        emptyStateOpenButton.setAccessibilityHelp(L10n.t("empty.hint", "Press Command+O to open a file, or Command+T to create a new tab."))

        emptyStateNewButton.title = L10n.t("empty.newTab", "New Tab")
        emptyStateNewButton.bezelStyle = .rounded
        emptyStateNewButton.target = self
        emptyStateNewButton.action = #selector(newTab)
        emptyStateNewButton.setAccessibilityLabel(L10n.t("empty.newTab", "New Tab"))
        emptyStateNewButton.setAccessibilityHelp(L10n.t("empty.hint", "Press Command+O to open a file, or Command+T to create a new tab."))

        emptyStateButtons.orientation = .horizontal
        emptyStateButtons.alignment = .centerY
        emptyStateButtons.spacing = 8
        emptyStateButtons.translatesAutoresizingMaskIntoConstraints = false
        emptyStateButtons.addArrangedSubview(emptyStateOpenButton)
        emptyStateButtons.addArrangedSubview(emptyStateNewButton)

        emptyStateView.addArrangedSubview(emptyStateTitleLabel)
        emptyStateView.addArrangedSubview(emptyStateHintLabel)
        emptyStateView.addArrangedSubview(emptyStateButtons)

        emptyStateTitleLabel.setAccessibilityLabel(L10n.t("empty.title", "No file is open"))
        emptyStateHintLabel.setAccessibilityLabel(L10n.t("empty.hint", "Press Command+O to open a file, or Command+T to create a new tab."))
    }

    func updateEmptyStateVisibility() {
        let hasTabs = tabView.numberOfTabViewItems > 0
        tabView.isHidden = !hasTabs
        emptyStateView.isHidden = hasTabs
    }
}

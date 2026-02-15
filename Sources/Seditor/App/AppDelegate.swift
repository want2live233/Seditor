import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, NSWindowDelegate, NSTabViewDelegate {
    let gutterWidth: CGFloat = 56
    let tabBarHeight: CGFloat = 34

    var window: NSWindow?
    let workspaceView = NSView(frame: .zero)
    let tabBarView = NSView(frame: .zero)
    let tabButtonsStack = NSStackView(frame: .zero)
    let newTabButton = NSButton(frame: .zero)
    let tabView = NSTabView(frame: .zero)
    var tabButtonsByID: [String: NSButton] = [:]

    var tabItemToSession: [ObjectIdentifier: EditorSession] = [:]
    var textViewToSession: [ObjectIdentifier: EditorSession] = [:]
    var clipViewToSession: [ObjectIdentifier: EditorSession] = [:]

    var untitledCounter = 1
    var editorFontSize: CGFloat = 14
    var editorTheme: EditorTheme = .system
    let redrawInterval: TimeInterval = 1.0 / 60.0

    lazy var autosaveDirectoryURL: URL = {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Seditor", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    lazy var sessionStateURL: URL = autosaveDirectoryURL.appendingPathComponent("sessions.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        restoreTabsOrCreateDefault()

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

        contentView.addSubview(workspaceView)
        workspaceView.addSubview(tabBarView)
        workspaceView.addSubview(tabView)
        tabBarView.addSubview(tabButtonsStack)
        tabBarView.addSubview(newTabButton)

        NSLayoutConstraint.activate([
            workspaceView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            workspaceView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            workspaceView.topAnchor.constraint(equalTo: contentView.topAnchor),
            workspaceView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            tabBarView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
            tabBarView.topAnchor.constraint(equalTo: workspaceView.topAnchor),
            tabBarView.heightAnchor.constraint(equalToConstant: tabBarHeight),

            tabButtonsStack.leadingAnchor.constraint(equalTo: tabBarView.leadingAnchor, constant: gutterWidth + 8),
            tabButtonsStack.trailingAnchor.constraint(lessThanOrEqualTo: newTabButton.leadingAnchor, constant: -8),
            tabButtonsStack.centerYAnchor.constraint(equalTo: tabBarView.centerYAnchor),

            newTabButton.trailingAnchor.constraint(equalTo: tabBarView.trailingAnchor, constant: -8),
            newTabButton.centerYAnchor.constraint(equalTo: tabBarView.centerYAnchor),

            tabView.leadingAnchor.constraint(equalTo: workspaceView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: workspaceView.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            tabView.bottomAnchor.constraint(equalTo: workspaceView.bottomAnchor)
        ])

        tabBarView.wantsLayer = true
        tabBarView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        tabBarView.layer?.zPosition = 100
        tabBarView.layer?.borderWidth = 1
        tabBarView.layer?.borderColor = NSColor.separatorColor.cgColor
    }

    func currentTabItem() -> NSTabViewItem? {
        tabView.selectedTabViewItem
    }

    func currentSession() -> EditorSession? {
        guard let item = currentTabItem() else { return nil }
        return tabItemToSession[ObjectIdentifier(item)]
    }

    func updateWindowTitle() {
        window?.title = ""
    }

    func focusCurrentEditor() {
        guard let window, let session = currentSession() else { return }
        window.makeFirstResponder(session.textView)
        session.textView.setSelectedRange(NSRange(location: 0, length: 0))
        requestRedraw(for: session, gutter: true, editor: true)
        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.currentSession() else { return }
            self.window?.makeFirstResponder(session.textView)
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        for (_, session) in tabItemToSession {
            session.saveWorkItem?.cancel()
            saveAutosave(for: session)
        }
        persistWorkspaceState()
    }
}

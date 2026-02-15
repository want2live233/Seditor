import AppKit

@MainActor
final class EditorSession {
    let id = UUID()
    let rootView = NSView(frame: .zero)
    let gutterView = GutterView(frame: .zero)
    let editorScrollView = NSScrollView(frame: .zero)
    let textView = EditorTextView(frame: .zero)

    var currentFileURL: URL?
    let autosaveURL: URL
    var saveWorkItem: DispatchWorkItem?
    var redrawWorkItem: DispatchWorkItem?
    var pendingGutterRedraw = false
    var pendingEditorRedraw = false

    init(autosaveURL: URL) {
        self.autosaveURL = autosaveURL
        configureViews()
    }

    private func configureViews() {
        rootView.translatesAutoresizingMaskIntoConstraints = true
        rootView.autoresizesSubviews = true

        gutterView.translatesAutoresizingMaskIntoConstraints = false
        editorScrollView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(gutterView)
        rootView.addSubview(editorScrollView)

        NSLayoutConstraint.activate([
            gutterView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            gutterView.topAnchor.constraint(equalTo: rootView.topAnchor),
            gutterView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            gutterView.widthAnchor.constraint(equalToConstant: 56),

            editorScrollView.leadingAnchor.constraint(equalTo: gutterView.trailingAnchor),
            editorScrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            editorScrollView.topAnchor.constraint(equalTo: rootView.topAnchor),
            editorScrollView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        editorScrollView.borderType = .noBorder
        editorScrollView.hasVerticalScroller = true
        editorScrollView.hasHorizontalScroller = false
        editorScrollView.autohidesScrollers = true
        editorScrollView.verticalScrollElasticity = .automatic

        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.frame = NSRect(x: 0, y: 0, width: 900, height: 1200)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 0, height: 10)

        editorScrollView.documentView = textView
        gutterView.textView = textView
    }
}

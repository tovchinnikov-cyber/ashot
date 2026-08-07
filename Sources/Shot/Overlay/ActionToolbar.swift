import AppKit

final class ActionToolbar: NSView {
    var onSelectTool: ((AnnotationTool?) -> Void)?
    var onUndo: (() -> Void)?
    var onCopy: (() -> Void)?

    private let stackView = NSStackView()
    private var arrowButton: HoverButton!
    private var rectButton: HoverButton!
    private var textButton: HoverButton!
    private var activeTool: AnnotationTool?

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 40))
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        layer?.cornerRadius = 10

        arrowButton = makeButton(symbol: "arrow.up.right", tooltip: "Arrow") { [weak self] in self?.toggleTool(.arrow) }
        rectButton = makeButton(symbol: "rectangle", tooltip: "Rectangle") { [weak self] in self?.toggleTool(.rectangle) }
        textButton = makeButton(symbol: "character.cursor.ibeam", tooltip: "Text") { [weak self] in self?.toggleTool(.text) }
        let undoButton = makeButton(symbol: "arrow.uturn.backward", tooltip: "Undo (⌘Z)") { [weak self] in self?.onUndo?() }

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 26).isActive = true

        let copyButton = makeButton(symbol: "doc.on.doc", tooltip: "Copy (⌘C)") { [weak self] in self?.onCopy?() }

        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8)
        stackView.addArrangedSubview(arrowButton)
        stackView.addArrangedSubview(rectButton)
        stackView.addArrangedSubview(textButton)
        stackView.addArrangedSubview(undoButton)
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(copyButton)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        setFrameSize(stackView.fittingSize)
    }

    private func toggleTool(_ tool: AnnotationTool) {
        if activeTool == tool {
            activeTool = nil
            updateToolHighlights()
            onSelectTool?(nil)
        } else {
            activeTool = tool
            updateToolHighlights()
            onSelectTool?(tool)
        }
    }

    private func updateToolHighlights() {
        arrowButton.isActive = activeTool == .arrow
        rectButton.isActive = activeTool == .rectangle
        textButton.isActive = activeTool == .text
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    private func makeButton(symbol: String, tooltip: String, action: @escaping () -> Void) -> HoverButton {
        let button = HoverButton(frame: NSRect(x: 0, y: 0, width: 40, height: 36))
        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)?.withSymbolConfiguration(config)
        button.contentTintColor = .white
        button.toolTip = tooltip
        button.target = self
        button.action = #selector(buttonClicked(_:))
        button.tag = buttons.count
        buttons.append(action)
        return button
    }

    private var buttons: [() -> Void] = []

    @objc private func buttonClicked(_ sender: NSButton) {
        guard sender.tag < buttons.count else { return }
        buttons[sender.tag]()
    }
}

final class HoverButton: NSButton {
    private var trackingArea: NSTrackingArea?
    var isActive: Bool = false {
        didSet { updateAppearance() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        bezelStyle = .accessoryBarAction
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isActive {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        updateAppearance()
    }

    private func updateAppearance() {
        if isActive {
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.5).cgColor
        } else {
            layer?.backgroundColor = nil
        }
    }
}

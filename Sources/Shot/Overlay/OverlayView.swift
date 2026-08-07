import AppKit
import QuartzCore

protocol OverlayViewDelegate: AnyObject {
    func overlayViewDidFinishSelection(_ view: OverlayView, rect: NSRect)
    func overlayViewDidCancel(_ view: OverlayView)
}

final class OverlayView: NSView, NSTextFieldDelegate {
    weak var delegate: OverlayViewDelegate?

    let capturedImage: CGImage
    let backingScaleFactor: CGFloat

    private var selection: SelectionGeometry?
    private var isSelecting = false
    private var isDragging = false
    private var activeHandle: SelectionGeometry.Handle?
    private var dragStartPoint: NSPoint = .zero
    private var dragStartSelection: SelectionGeometry?

    private var actionToolbar: ActionToolbar?

    // Annotations
    private var activeTool: AnnotationTool?
    private var annotations: [Annotation] = []
    private var annotationLayers: [CAShapeLayer] = []
    private var currentAnnotation: Annotation?
    private var currentAnnotationLayer: CAShapeLayer?
    private var isDrawingAnnotation = false

    // Text annotations
    private var textAnnotations: [TextAnnotation] = []
    private var textLayers: [CATextLayer] = []
    private var activeTextField: NSTextField?
    private var activeTextPosition: NSPoint = .zero

    private enum HistoryItem { case shape, text }
    private var history: [HistoryItem] = []

    // Layers
    private let imageLayer = CALayer()
    private let dimmingLayer = CAShapeLayer()
    private let selectionBorderLayer = CAShapeLayer()
    private let handleLayers: [CAShapeLayer] = (0..<8).map { _ in CAShapeLayer() }
    private let sizeLabelLayer = CATextLayer()
    private let sizeLabelBgLayer = CALayer()

    override var isFlipped: Bool { true }

    init(frame: NSRect, capturedImage: CGImage, backingScaleFactor: CGFloat) {
        self.capturedImage = capturedImage
        self.backingScaleFactor = backingScaleFactor
        super.init(frame: frame)
        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func setupLayers() {
        wantsLayer = true
        guard let rootLayer = layer else { return }
        rootLayer.isGeometryFlipped = true

        imageLayer.frame = bounds
        imageLayer.contents = capturedImage
        imageLayer.contentsGravity = .resizeAspectFill
        rootLayer.addSublayer(imageLayer)

        dimmingLayer.frame = bounds
        dimmingLayer.fillColor = NSColor.black.withAlphaComponent(0.4).cgColor
        dimmingLayer.fillRule = .evenOdd
        let fullPath = CGMutablePath()
        fullPath.addRect(bounds)
        dimmingLayer.path = fullPath
        rootLayer.addSublayer(dimmingLayer)

        selectionBorderLayer.fillColor = nil
        selectionBorderLayer.strokeColor = NSColor.white.withAlphaComponent(0.8).cgColor
        selectionBorderLayer.lineWidth = 1.5
        selectionBorderLayer.isHidden = true
        rootLayer.addSublayer(selectionBorderLayer)

        for handleLayer in handleLayers {
            handleLayer.fillColor = NSColor.white.cgColor
            handleLayer.strokeColor = NSColor(white: 0.3, alpha: 1).cgColor
            handleLayer.lineWidth = 1
            handleLayer.isHidden = true
            rootLayer.addSublayer(handleLayer)
        }

        sizeLabelBgLayer.backgroundColor = NSColor.black.withAlphaComponent(0.7).cgColor
        sizeLabelBgLayer.cornerRadius = 4
        sizeLabelBgLayer.isHidden = true
        rootLayer.addSublayer(sizeLabelBgLayer)

        sizeLabelLayer.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        sizeLabelLayer.fontSize = 12
        sizeLabelLayer.foregroundColor = NSColor.white.cgColor
        sizeLabelLayer.alignmentMode = .center
        sizeLabelLayer.contentsScale = backingScaleFactor
        sizeLabelLayer.isHidden = true
        rootLayer.addSublayer(sizeLabelLayer)
    }

    private func updateSelectionLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        guard let sel = selection, !sel.isEmpty else {
            let fullPath = CGMutablePath()
            fullPath.addRect(bounds)
            dimmingLayer.path = fullPath
            selectionBorderLayer.isHidden = true
            handleLayers.forEach { $0.isHidden = true }
            sizeLabelBgLayer.isHidden = true
            sizeLabelLayer.isHidden = true
            CATransaction.commit()
            return
        }

        let selRect = sel.rect

        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRect(selRect)
        dimmingLayer.path = path

        selectionBorderLayer.path = CGPath(rect: selRect, transform: nil)
        selectionBorderLayer.isHidden = false

        if !isSelecting && activeTool == nil {
            let handles = sel.handleRects()
            let allHandles = SelectionGeometry.Handle.allCases
            for (i, handle) in allHandles.enumerated() {
                if let rect = handles[handle] {
                    handleLayers[i].path = CGPath(ellipseIn: rect, transform: nil)
                    handleLayers[i].isHidden = false
                }
            }
        } else {
            handleLayers.forEach { $0.isHidden = true }
        }

        let pixelRect = sel.pixelRect(scaleFactor: backingScaleFactor)
        let text = "\(Int(pixelRect.width)) × \(Int(pixelRect.height))"
        sizeLabelLayer.string = text

        let textSize = (text as NSString).size(withAttributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        ])
        let padding: CGFloat = 6
        let labelW = textSize.width + padding * 2
        let labelH = textSize.height + padding

        var labelY = selRect.minY - labelH - 4
        if labelY < bounds.minY + 4 {
            labelY = selRect.maxY + 4
        }
        let labelX = max(bounds.minX + 4, selRect.maxX - labelW)

        sizeLabelBgLayer.frame = CGRect(x: labelX, y: labelY, width: labelW, height: labelH)
        sizeLabelBgLayer.isHidden = false

        sizeLabelLayer.frame = CGRect(x: labelX, y: labelY, width: labelW, height: labelH)
        sizeLabelLayer.isHidden = false

        CATransaction.commit()
    }

    // MARK: - Annotation layer management

    private func makeAnnotationLayer(for annotation: Annotation) -> CAShapeLayer {
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = annotation.createPath()
        shapeLayer.strokeColor = annotation.color.cgColor
        shapeLayer.lineWidth = annotation.lineWidth
        shapeLayer.lineCap = .round
        shapeLayer.lineJoin = .round

        switch annotation.tool {
        case .arrow, .rectangle, .text:
            shapeLayer.fillColor = nil
        }

        return shapeLayer
    }

    private func undoLastAnnotation() {
        guard let last = history.popLast() else { return }
        switch last {
        case .shape:
            annotations.removeLast()
            annotationLayers.popLast()?.removeFromSuperlayer()
        case .text:
            textAnnotations.removeLast()
            textLayers.popLast()?.removeFromSuperlayer()
        }
    }

    // MARK: - Text annotations

    func cancelTextEntryIfActive() -> Bool {
        guard activeTextField != nil else { return false }
        cancelActiveTextField()
        window?.makeFirstResponder(self)
        return true
    }

    private func beginTextEntry(at point: NSPoint) {
        cancelActiveTextField()

        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 220, height: 28))
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.black.withAlphaComponent(0.55)
        field.textColor = .systemRed
        field.font = .boldSystemFont(ofSize: 20)
        field.focusRingType = .none
        field.delegate = self
        addSubview(field)
        window?.makeFirstResponder(field)

        activeTextField = field
        activeTextPosition = point
    }

    private func cancelActiveTextField() {
        guard let field = activeTextField else { return }
        activeTextField = nil
        field.removeFromSuperview()
    }

    private func commitActiveTextField() {
        guard let field = activeTextField else { return }
        activeTextField = nil
        field.removeFromSuperview()

        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let annotation = TextAnnotation(
            text: text,
            position: activeTextPosition,
            font: field.font ?? .boldSystemFont(ofSize: 20),
            color: .systemRed
        )
        let textLayer = makeTextLayer(for: annotation)
        layer?.addSublayer(textLayer)
        textAnnotations.append(annotation)
        textLayers.append(textLayer)
        history.append(.text)
    }

    private func makeTextLayer(for annotation: TextAnnotation) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.string = annotation.text
        textLayer.font = annotation.font
        textLayer.fontSize = annotation.font.pointSize
        textLayer.foregroundColor = annotation.color.cgColor
        textLayer.contentsScale = backingScaleFactor
        let size = (annotation.text as NSString).size(withAttributes: [.font: annotation.font])
        textLayer.frame = CGRect(
            origin: annotation.position,
            size: CGSize(width: ceil(size.width) + 4, height: ceil(size.height) + 4)
        )
        return textLayer
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitActiveTextField()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            window?.makeFirstResponder(self)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelActiveTextField()
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        if activeTextField != nil {
            window?.makeFirstResponder(self)
        }

        let point = convert(event.locationInWindow, from: nil)

        // If annotation tool is active and we have a selection, start drawing annotation
        if let tool = activeTool, let sel = selection, !sel.isEmpty, sel.rect.contains(point) {
            if tool == .text {
                beginTextEntry(at: point)
                return
            }
            isDrawingAnnotation = true
            dragStartPoint = point
            currentAnnotation = Annotation(tool: tool, startPoint: point, endPoint: point)
            let tempLayer = makeAnnotationLayer(for: currentAnnotation!)
            layer?.addSublayer(tempLayer)
            currentAnnotationLayer = tempLayer
            return
        }

        // If we have a selection, check handles and dragging
        if let sel = selection, !sel.isEmpty {
            if activeTool == nil {
                if let handle = sel.hitTestHandle(at: point) {
                    activeHandle = handle
                    dragStartPoint = point
                    dragStartSelection = sel
                    return
                }
                if sel.rect.contains(point) {
                    isDragging = true
                    dragStartPoint = point
                    dragStartSelection = sel
                    return
                }
            }
        }

        // Start new selection
        removeActionToolbar()
        clearAnnotations()
        activeTool = nil
        isSelecting = true
        dragStartPoint = point
        selection = SelectionGeometry(origin: point, size: .zero)
        updateSelectionLayers()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clampedPoint = NSPoint(
            x: max(bounds.minX, min(bounds.maxX, point.x)),
            y: max(bounds.minY, min(bounds.maxY, point.y))
        )

        if isDrawingAnnotation, let tool = activeTool {
            currentAnnotation = Annotation(tool: tool, startPoint: dragStartPoint, endPoint: clampedPoint)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            currentAnnotationLayer?.path = currentAnnotation!.createPath()
            CATransaction.commit()
            return
        }

        if let handle = activeHandle, let startSel = dragStartSelection {
            selection = startSel.resized(handle: handle, to: clampedPoint)
        } else if isDragging, let startSel = dragStartSelection {
            let delta = NSPoint(x: clampedPoint.x - dragStartPoint.x, y: clampedPoint.y - dragStartPoint.y)
            selection = startSel.moved(delta: delta).clamped(to: bounds)
        } else if isSelecting {
            selection = SelectionGeometry(
                origin: dragStartPoint,
                size: NSSize(width: clampedPoint.x - dragStartPoint.x, height: clampedPoint.y - dragStartPoint.y)
            )
        }

        updateSelectionLayers()
    }

    override func mouseUp(with event: NSEvent) {
        if isDrawingAnnotation {
            isDrawingAnnotation = false
            if let annotation = currentAnnotation {
                let dx = annotation.endPoint.x - annotation.startPoint.x
                let dy = annotation.endPoint.y - annotation.startPoint.y
                if hypot(dx, dy) > 3 {
                    annotations.append(annotation)
                    if let shapeLayer = currentAnnotationLayer {
                        annotationLayers.append(shapeLayer)
                    }
                    history.append(.shape)
                } else {
                    currentAnnotationLayer?.removeFromSuperlayer()
                }
            }
            currentAnnotation = nil
            currentAnnotationLayer = nil
            return
        }

        if isSelecting || activeHandle != nil || isDragging {
            isSelecting = false
            activeHandle = nil
            isDragging = false
            dragStartSelection = nil

            if let sel = selection, !sel.isEmpty {
                updateSelectionLayers()
                showActionToolbar(for: sel)
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateCursor(at: point)
    }

    private func updateCursor(at point: NSPoint) {
        if let toolbar = actionToolbar, toolbar.frame.contains(point) {
            NSCursor.arrow.set()
            return
        }

        if let tool = activeTool {
            (tool == .text ? NSCursor.iBeam : NSCursor.crosshair).set()
            return
        }

        if let sel = selection, !sel.isEmpty {
            if let handle = sel.hitTestHandle(at: point) {
                SelectionGeometry.cursorForHandle(handle).set()
                return
            }
            if sel.rect.contains(point) {
                NSCursor.openHand.set()
                return
            }
        }
        NSCursor.crosshair.set()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited],
            owner: self
        ))
    }

    // MARK: - Keyboard shortcuts

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if event.keyCode == 0x35 {
            delegate?.overlayViewDidCancel(self)
            return
        }

        if event.keyCode == 0x08 && flags == .command {
            handleCopy()
            return
        }

        // Cmd+Z → undo
        if event.keyCode == 0x06 && flags == .command {
            undoLastAnnotation()
            return
        }

        if event.keyCode == 0x24 {
            handleCopy()
            return
        }
    }

    // MARK: - Action Toolbar

    private func showActionToolbar(for sel: SelectionGeometry) {
        removeActionToolbar()

        let toolbar = ActionToolbar()
        toolbar.onSelectTool = { [weak self] tool in
            self?.activeTool = tool
            self?.updateSelectionLayers()
        }
        toolbar.onUndo = { [weak self] in self?.undoLastAnnotation() }
        toolbar.onCopy = { [weak self] in self?.handleCopy() }

        let selRect = sel.rect
        let toolbarSize = toolbar.frame.size
        var toolbarOrigin = NSPoint(
            x: selRect.maxX - toolbarSize.width,
            y: selRect.maxY + 8
        )

        // Y: prefer below selection, fallback above, then clamp inside selection
        if toolbarOrigin.y + toolbarSize.height > bounds.maxY - 4 {
            toolbarOrigin.y = selRect.minY - toolbarSize.height - 8
        }
        if toolbarOrigin.y < bounds.minY + 4 {
            toolbarOrigin.y = selRect.maxY - toolbarSize.height - 8
        }

        // Clamp to stay within screen on all sides
        toolbarOrigin.x = min(toolbarOrigin.x, bounds.maxX - toolbarSize.width - 4)
        toolbarOrigin.x = max(bounds.minX + 4, toolbarOrigin.x)
        toolbarOrigin.y = min(toolbarOrigin.y, bounds.maxY - toolbarSize.height - 4)
        toolbarOrigin.y = max(bounds.minY + 4, toolbarOrigin.y)

        toolbar.setFrameOrigin(toolbarOrigin)
        addSubview(toolbar)
        self.actionToolbar = toolbar
    }

    private func removeActionToolbar() {
        actionToolbar?.removeFromSuperview()
        actionToolbar = nil
    }

    private func clearAnnotations() {
        cancelActiveTextField()
        for layer in annotationLayers {
            layer.removeFromSuperlayer()
        }
        annotationLayers.removeAll()
        annotations.removeAll()
        for layer in textLayers {
            layer.removeFromSuperlayer()
        }
        textLayers.removeAll()
        textAnnotations.removeAll()
        history.removeAll()
    }

    // MARK: - Capture with annotations

    private func renderCroppedImage() -> CGImage? {
        guard let sel = selection, !sel.isEmpty else { return nil }
        let pixelRect = sel.pixelRect(scaleFactor: backingScaleFactor)
        guard let cropped = capturedImage.cropping(to: pixelRect) else { return nil }

        if annotations.isEmpty && textAnnotations.isEmpty { return cropped }

        // Render annotations onto the cropped image
        let width = Int(pixelRect.width)
        let height = Int(pixelRect.height)
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return cropped }

        // Draw the cropped screenshot
        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip to match our view coordinates (isFlipped = true)
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1, y: -1)

        let selRect = sel.rect
        let scale = backingScaleFactor

        for annotation in annotations {
            let offsetStart = NSPoint(
                x: (annotation.startPoint.x - selRect.origin.x) * scale,
                y: (annotation.startPoint.y - selRect.origin.y) * scale
            )
            let offsetEnd = NSPoint(
                x: (annotation.endPoint.x - selRect.origin.x) * scale,
                y: (annotation.endPoint.y - selRect.origin.y) * scale
            )
            let offsetAnnotation = Annotation(
                tool: annotation.tool,
                startPoint: offsetStart,
                endPoint: offsetEnd
            )

            ctx.setStrokeColor(annotation.color.cgColor)
            ctx.setLineWidth(annotation.lineWidth * scale)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(offsetAnnotation.createPath())
            ctx.strokePath()
        }

        for textAnnotation in textAnnotations {
            let offsetPosition = NSPoint(
                x: (textAnnotation.position.x - selRect.origin.x) * scale,
                y: (textAnnotation.position.y - selRect.origin.y) * scale
            )
            let scaledFont = NSFont(
                descriptor: textAnnotation.font.fontDescriptor,
                size: textAnnotation.font.pointSize * scale
            ) ?? textAnnotation.font

            // NSAttributedString drawing (not raw CGContext text APIs) correctly
            // respects the flipped coordinate system set up above.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
            let attrString = NSAttributedString(string: textAnnotation.text, attributes: [
                .font: scaledFont,
                .foregroundColor: textAnnotation.color,
            ])
            attrString.draw(at: offsetPosition)
            NSGraphicsContext.restoreGraphicsState()
        }

        return ctx.makeImage()
    }

    private func handleCopy() {
        if let image = renderCroppedImage() {
            ClipboardManager.copy(image)
        }
        delegate?.overlayViewDidFinishSelection(self, rect: selection?.rect ?? .zero)
    }
}

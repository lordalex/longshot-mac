import AppKit
import Foundation

final class SelectionOverlayController {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private let completion: (CGRect?) -> Void

    init(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
    }

    func begin() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.finish(nil)
                return nil
            }
            return event
        }

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false

            let selectionView = SelectionView(screenFrame: screen.frame)
            selectionView.onFinished = { [weak self] rect in
                self?.finish(rect)
            }
            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
    }

    private func finish(_ rect: CGRect?) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }

        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        completion(rect)
    }
}

final class SelectionView: NSView {
    var onFinished: ((CGRect?) -> Void)?

    private let screenFrame: CGRect
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        cursorUpdate(with: NSEvent())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.34).setFill()
        bounds.fill()

        if let rect = selectionRect {
            NSColor.white.withAlphaComponent(0.16).setFill()
            rect.fill()

            let border = NSBezierPath(rect: rect)
            border.lineWidth = 2
            NSColor.white.setStroke()
            border.stroke()

            drawInstruction(inside: rect)
        } else {
            drawCenteredInstruction()
        }
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        let minX = min(startPoint.x, currentPoint.x)
        let minY = min(startPoint.y, currentPoint.y)
        let maxX = max(startPoint.x, currentPoint.x)
        let maxY = max(startPoint.y, currentPoint.y)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = event.locationInWindow
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = event.locationInWindow
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = event.locationInWindow
        guard let rect = selectionRect, rect.width >= 24, rect.height >= 24 else {
            onFinished?(nil)
            return
        }

        let global = rect.offsetBy(dx: screenFrame.origin.x, dy: screenFrame.origin.y)
        onFinished?(global)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onFinished?(nil)
        }
    }

    private func drawCenteredInstruction() {
        let text = "Drag over the scrollable page content. Avoid browser chrome. Press Esc to cancel."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2, width: size.width, height: size.height)
        text.draw(in: rect, withAttributes: attributes)
    }

    private func drawInstruction(inside rect: CGRect) {
        let text = "\(Int(rect.width)) x \(Int(rect.height))  •  Release to capture"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        text.draw(at: CGPoint(x: rect.minX + 8, y: rect.maxY + 8), withAttributes: attributes)
    }
}

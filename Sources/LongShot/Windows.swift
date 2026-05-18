import AppKit
import Foundation

final class StartWindowController: NSWindowController {
    private let startView: StartView

    init(
        captureAction: @escaping () -> Void,
        permissionsAction: @escaping () -> Void,
        folderAction: @escaping () -> Void,
        settingsAction: @escaping (CaptureSettings) -> Void
    ) {
        let view = StartView(
            frame: CGRect(x: 0, y: 0, width: 520, height: 360),
            captureAction: captureAction,
            permissionsAction: permissionsAction,
            folderAction: folderAction,
            settingsAction: settingsAction
        )
        self.startView = view

        let window = NSWindow(
            contentRect: view.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 520, height: 360)
        window.title = "LongShot"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(settings: CaptureSettings, screenRecordingGranted: Bool, accessibilityGranted: Bool) {
        startView.update(settings: settings, screenRecordingGranted: screenRecordingGranted, accessibilityGranted: accessibilityGranted)
    }
}

final class StartView: NSView {
    private let captureAction: () -> Void
    private let permissionsAction: () -> Void
    private let folderAction: () -> Void
    private let settingsAction: (CaptureSettings) -> Void

    private let screenStatus = NSTextField(labelWithString: "")
    private let accessibilityStatus = NSTextField(labelWithString: "")
    private let speedPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let lengthPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let delayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var currentSettings = CaptureSettings.load()

    init(
        frame: CGRect,
        captureAction: @escaping () -> Void,
        permissionsAction: @escaping () -> Void,
        folderAction: @escaping () -> Void,
        settingsAction: @escaping (CaptureSettings) -> Void
    ) {
        self.captureAction = captureAction
        self.permissionsAction = permissionsAction
        self.folderAction = folderAction
        self.settingsAction = settingsAction
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build() {
        addGlassBackground()

        if let icon = NSImage(named: "AppIcon") ?? NSImage(contentsOf: Bundle.main.url(forResource: "AppIcon", withExtension: "png") ?? URL(fileURLWithPath: "")) {
            let iconView = NSImageView(frame: CGRect(x: 28, y: 274, width: 56, height: 56))
            iconView.image = icon
            iconView.imageScaling = .scaleProportionallyUpOrDown
            addSubview(iconView)
        }

        let title = label("LongShot", font: .systemFont(ofSize: 28, weight: .bold), color: .labelColor)
        title.frame = CGRect(x: 96, y: 292, width: 300, height: 34)

        let subtitle = label("Capture long scrolling pages from any selected area.", font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
        subtitle.frame = CGRect(x: 98, y: 270, width: 360, height: 22)

        let captureButton = NSButton(title: "Capture Long Page", target: self, action: #selector(capturePressed))
        captureButton.bezelStyle = .rounded
        captureButton.controlSize = .large
        captureButton.keyEquivalent = "\r"
        captureButton.frame = CGRect(x: 28, y: 218, width: 196, height: 38)

        let permissionsButton = NSButton(title: "Check Permissions", target: self, action: #selector(permissionsPressed))
        permissionsButton.bezelStyle = .rounded
        permissionsButton.frame = CGRect(x: 238, y: 222, width: 150, height: 30)

        let folderButton = NSButton(title: "Open Captures Folder", target: self, action: #selector(folderPressed))
        folderButton.bezelStyle = .rounded
        folderButton.frame = CGRect(x: 398, y: 222, width: 96, height: 30)
        folderButton.title = "Folder"

        let permissionPanel = GlassPanelView(frame: CGRect(x: 22, y: 136, width: 476, height: 70))
        let settingsPanel = GlassPanelView(frame: CGRect(x: 22, y: 68, width: 476, height: 58))

        let permissionsTitle = label("Permissions", font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabelColor)
        permissionsTitle.frame = CGRect(x: 30, y: 180, width: 160, height: 18)
        screenStatus.frame = CGRect(x: 30, y: 153, width: 220, height: 22)
        accessibilityStatus.frame = CGRect(x: 270, y: 153, width: 220, height: 22)

        let settingsTitle = label("Capture Settings", font: .systemFont(ofSize: 13, weight: .semibold), color: .secondaryLabelColor)
        settingsTitle.frame = CGRect(x: 30, y: 116, width: 160, height: 18)

        configurePopup(speedPopup, items: ["Balanced scroll", "Careful scroll", "Fast scroll"], action: #selector(settingsChanged))
        configurePopup(lengthPopup, items: ["Medium page", "Short page", "Very long page"], action: #selector(settingsChanged))
        configurePopup(delayPopup, items: ["Normal delay", "Longer delay", "Short delay"], action: #selector(settingsChanged))
        speedPopup.frame = CGRect(x: 30, y: 78, width: 145, height: 30)
        lengthPopup.frame = CGRect(x: 188, y: 78, width: 145, height: 30)
        delayPopup.frame = CGRect(x: 346, y: 78, width: 145, height: 30)

        let hint = label("Select only the scrollable content area. Keep the pointer still while LongShot captures and scrolls.", font: .systemFont(ofSize: 12), color: .tertiaryLabelColor)
        hint.frame = CGRect(x: 30, y: 31, width: 460, height: 34)

        addSubview(permissionPanel)
        addSubview(settingsPanel)
        addSubview(title)
        addSubview(subtitle)
        addSubview(captureButton)
        addSubview(permissionsButton)
        addSubview(folderButton)
        addSubview(permissionsTitle)
        addSubview(screenStatus)
        addSubview(accessibilityStatus)
        addSubview(settingsTitle)
        addSubview(speedPopup)
        addSubview(lengthPopup)
        addSubview(delayPopup)
        addSubview(hint)
        update(settings: currentSettings, screenRecordingGranted: false, accessibilityGranted: false)
    }

    private func addGlassBackground() {
        let material = NSVisualEffectView(frame: bounds)
        material.autoresizingMask = [.width, .height]
        material.blendingMode = .behindWindow
        material.material = .underWindowBackground
        material.state = .active
        addSubview(material)

        let accent = AccentWashView(frame: bounds)
        accent.autoresizingMask = [.width, .height]
        addSubview(accent)
    }

    func update(settings: CaptureSettings, screenRecordingGranted: Bool, accessibilityGranted: Bool) {
        currentSettings = settings
        screenStatus.attributedStringValue = statusString(title: "Screen Recording", granted: screenRecordingGranted)
        accessibilityStatus.attributedStringValue = statusString(title: "Accessibility", granted: accessibilityGranted)

        speedPopup.selectItem(at: settings.scrollFraction < 0.65 ? 1 : (settings.scrollFraction > 0.80 ? 2 : 0))
        lengthPopup.selectItem(at: settings.maxFrames <= 18 ? 1 : (settings.maxFrames >= 60 ? 2 : 0))
        delayPopup.selectItem(at: settings.settleDelay > 0.60 ? 1 : (settings.settleDelay < 0.30 ? 2 : 0))
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        return field
    }

    private func configurePopup(_ popup: NSPopUpButton, items: [String], action: Selector) {
        popup.removeAllItems()
        popup.addItems(withTitles: items)
        popup.target = self
        popup.action = action
    }

    private func statusString(title: String, granted: Bool) -> NSAttributedString {
        let text = "\(granted ? "✓" : "!") \(title)"
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor
            ]
        )
        attributed.addAttribute(
            .foregroundColor,
            value: granted ? NSColor.secondaryLabelColor : NSColor.systemOrange,
            range: NSRange(location: 0, length: 1)
        )
        return attributed
    }

    @objc private func capturePressed() {
        captureAction()
    }

    @objc private func permissionsPressed() {
        permissionsAction()
    }

    @objc private func folderPressed() {
        folderAction()
    }

    @objc private func settingsChanged() {
        var settings = CaptureSettings.defaults

        switch speedPopup.indexOfSelectedItem {
        case 1:
            settings.scrollFraction = 0.58
        case 2:
            settings.scrollFraction = 0.86
        default:
            settings.scrollFraction = 0.72
        }

        switch lengthPopup.indexOfSelectedItem {
        case 1:
            settings.maxFrames = 18
        case 2:
            settings.maxFrames = 72
        default:
            settings.maxFrames = 36
        }

        switch delayPopup.indexOfSelectedItem {
        case 1:
            settings.settleDelay = 0.70
        case 2:
            settings.settleDelay = 0.25
        default:
            settings.settleDelay = 0.42
        }

        currentSettings = settings
        settingsAction(settings)
    }
}

final class AccentWashView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let topBand = NSBezierPath(roundedRect: CGRect(x: 14, y: bounds.height - 118, width: bounds.width - 28, height: 86), xRadius: 18, yRadius: 18)
        NSColor.controlBackgroundColor.withAlphaComponent(0.48).setFill()
        topBand.fill()

        let lowerBand = NSBezierPath(roundedRect: CGRect(x: 18, y: 18, width: bounds.width - 36, height: 72), xRadius: 16, yRadius: 16)
        NSColor.white.withAlphaComponent(0.10).setFill()
        lowerBand.fill()
    }
}

final class GlassPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor.controlBackgroundColor.withAlphaComponent(0.32).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.24).setFill()
        NSBezierPath(roundedRect: CGRect(x: 1, y: rect.maxY - 5, width: rect.width - 2, height: 4), xRadius: 2, yRadius: 2).fill()

        NSColor.separatorColor.withAlphaComponent(0.18).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class ProgressWindowController: NSWindowController {
    private let label = NSTextField(labelWithString: "Starting...")
    private let spinner = NSProgressIndicator()

    init() {
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 340, height: 96))

        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.startAnimation(nil)
        spinner.frame = CGRect(x: 24, y: 34, width: 28, height: 28)

        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = CGRect(x: 66, y: 32, width: 248, height: 32)

        content.addSubview(spinner)
        content.addSubview(label)

        let window = NSWindow(
            contentRect: content.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "LongShot"
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(message: String) {
        label.stringValue = message
    }
}

final class PreviewWindowController: NSWindowController {
    private let imageURL: URL
    private let image: NSImage?

    init(imageURL: URL) {
        self.imageURL = imageURL
        self.image = NSImage(contentsOf: imageURL)
        let viewportSize = CGSize(width: 760, height: 900)
        let displaySize = PreviewWindowController.fitSize(for: image, maxWidth: viewportSize.width - 18)

        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = CGRect(origin: .zero, size: displaySize)
        imageView.autoresizingMask = []

        let scrollView = NSScrollView(frame: CGRect(origin: .zero, size: viewportSize))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = imageView

        let window = NSWindow(
            contentRect: scrollView.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = imageURL.lastPathComponent
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        window.center()

        super.init(window: window)

        let toolbar = NSToolbar(identifier: "LongShotPreviewToolbar")
        toolbar.delegate = self
        window.toolbar = toolbar
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func fitSize(for image: NSImage?, maxWidth: CGFloat) -> CGSize {
        let fallback = CGSize(width: maxWidth, height: 900)
        guard let representation = image?.representations.first else {
            guard let imageSize = image?.size, imageSize.width > 0 else { return fallback }
            let width = min(maxWidth, imageSize.width)
            return CGSize(width: width, height: imageSize.height * width / imageSize.width)
        }

        let pixelSize = CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        guard pixelSize.width > 0, pixelSize.height > 0 else { return fallback }

        let width = min(maxWidth, pixelSize.width)
        return CGSize(width: width, height: pixelSize.height * width / pixelSize.width)
    }
}

extension PreviewWindowController: NSToolbarDelegate {
    private static let revealItem = NSToolbarItem.Identifier("RevealInFinder")
    private static let openItem = NSToolbarItem.Identifier("OpenInPreview")
    private static let copyItem = NSToolbarItem.Identifier("CopyImage")

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.revealItem, Self.openItem, Self.copyItem, .flexibleSpace]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.revealItem, Self.openItem, Self.copyItem, .flexibleSpace]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case Self.revealItem:
            return toolbarItem(identifier: itemIdentifier, title: "Reveal", imageName: NSImage.revealFreestandingTemplateName, action: #selector(revealInFinder))
        case Self.openItem:
            return toolbarItem(identifier: itemIdentifier, title: "Open", imageName: NSImage.quickLookTemplateName, action: #selector(openInPreview))
        case Self.copyItem:
            return toolbarItem(identifier: itemIdentifier, title: "Copy", imageName: NSImage.multipleDocumentsName, action: #selector(copyImage))
        default:
            return nil
        }
    }

    private func toolbarItem(identifier: NSToolbarItem.Identifier, title: String, imageName: String, action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = title
        item.paletteLabel = title
        item.toolTip = title
        item.image = NSImage(named: imageName)
        item.target = self
        item.action = action
        return item
    }

    @objc private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([imageURL])
    }

    @objc private func openInPreview() {
        NSWorkspace.shared.open(imageURL)
    }

    @objc private func copyImage() {
        guard let image else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

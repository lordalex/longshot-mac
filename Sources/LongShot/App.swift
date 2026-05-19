import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@main
struct LongShotApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var captureManager: CaptureManager!
    private var overlayController: SelectionOverlayController?
    private var startController: StartWindowController?
    private var previewController: PreviewWindowController?
    private var lastCaptureURL: URL?
    private var isCapturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        captureManager = CaptureManager()
        configureMenu()
        showStartWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStartWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureStatusIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show LongShot", action: #selector(showLongShot), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Capture Long Page", action: #selector(captureLongPage), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Open Captures Folder", action: #selector(openCapturesFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Open Last Capture", action: #selector(openLastCapture), keyEquivalent: "o"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func configureStatusIcon() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.toolTip = "LongShot"

        if let url = Bundle.main.url(forResource: "StatusIconTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            button.image = image
            button.imagePosition = .imageOnly
        }
    }

    @objc private func showLongShot() {
        showStartWindow()
    }

    private func showStartWindow() {
        if let window = startController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = StartWindowController(
            captureAction: { [weak self] in self?.captureLongPage() },
            permissionsAction: { [weak self] in self?.checkPermissions() },
            folderAction: { [weak self] in self?.openCapturesFolder() },
            settingsAction: { [weak self] settings in
                self?.captureManager.settings = settings
                settings.save()
            }
        )
        startController = controller
        updateStartWindowStatus()
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func captureLongPage() {
        guard !isCapturing else { return }

        guard isRunningFromApplicationsFolder() else {
            showInfo("Use the installed app at /Applications/LongShot.app. macOS can repeatedly lose Screen Recording permission for development builds launched from the build folder.")
            return
        }

        captureManager.settings = CaptureSettings.load()
        guard ensurePermissions(showSuccess: false) else { return }

        NSApp.activate(ignoringOtherApps: true)
        overlayController = SelectionOverlayController { [weak self] rect in
            guard let self else { return }
            self.overlayController = nil
            guard let rect, rect.width > 24, rect.height > 24 else { return }
            self.startCapture(region: rect)
        }
        overlayController?.begin()
    }

    private func startCapture(region: CGRect) {
        isCapturing = true
        statusItem.button?.toolTip = "LongShot: Capturing..."
        startController?.window?.orderOut(nil)
        NSApp.hide(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self else { return }
            self.captureManager.captureLongPage(region: region, progress: { [weak self] message in
                DispatchQueue.main.async {
                    self?.statusItem.button?.toolTip = "LongShot: \(message)"
                }
            }, completion: { [weak self] result in
                DispatchQueue.main.async {
                    self?.isCapturing = false
                    self?.statusItem.button?.toolTip = "LongShot"
                    NSApp.unhide(nil)
                    switch result {
                    case .success(let url):
                        self?.lastCaptureURL = url
                        self?.showPreview(url: url)
                    case .failure(let error):
                        self?.showError(error.localizedDescription)
                    }
                }
            })
        }
    }

    @objc private func checkPermissions() {
        _ = ensurePermissions(showSuccess: true)
    }

    private func ensurePermissions(showSuccess: Bool = false) -> Bool {
        var missing: [String] = []

        if !CGPreflightScreenCaptureAccess() {
            missing.append("Screen Recording")
        }

        if !AXIsProcessTrusted() {
            missing.append("Accessibility")
        }

        if missing.isEmpty {
            if showSuccess {
                showInfo("Permissions look ready.")
            }
            updateStartWindowStatus()
            return true
        }

        showPermissionsAlert(missing: missing)
        updateStartWindowStatus()
        return false
    }

    private func showPermissionsAlert(missing: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "LongShot needs permission before it can capture windows"
        alert.informativeText = "macOS currently reports missing \(missing.joined(separator: " and ")). Enable /Applications/LongShot.app in Privacy & Security. Without Screen Recording permission, captures can contain only the wallpaper behind your windows."
        alert.addButton(withTitle: "Open Privacy Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            openPrivacySettings()
        }
    }

    private func openPrivacySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]

        for value in urls {
            if let url = URL(string: value) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func isRunningFromApplicationsFolder() -> Bool {
        let path = Bundle.main.bundleURL.standardizedFileURL.path
        return path == "/Applications/LongShot.app"
    }

    private func updateStartWindowStatus() {
        startController?.update(
            settings: CaptureSettings.load(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            accessibilityGranted: AXIsProcessTrusted()
        )
    }

    private func showPreview(url: URL) {
        previewController = PreviewWindowController(imageURL: url)
        previewController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openLastCapture() {
        guard let lastCaptureURL else {
            showInfo("No capture has been created yet.")
            return
        }
        NSWorkspace.shared.open(lastCaptureURL)
    }

    @objc private func openCapturesFolder() {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("LongShot", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func showInfo(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "LongShot"
        alert.informativeText = message
        alert.runModal()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Capture failed"
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(captureLongPage):
            return !isCapturing
        case #selector(openLastCapture):
            return lastCaptureURL != nil
        default:
            return true
        }
    }
}

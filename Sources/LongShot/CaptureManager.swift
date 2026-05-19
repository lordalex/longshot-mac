import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit

enum CaptureError: LocalizedError {
    case screenRecordingPermissionMissing
    case blankCapture
    case screenshotFailed
    case noDisplayForRegion
    case noImages
    case stitchFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionMissing:
            return "Screen Recording permission is not enabled for this copy of LongShot, so macOS will not include your windows in the screenshot."
        case .blankCapture:
            return "macOS returned a blank screen capture. Re-enable Screen Recording for /Applications/LongShot.app, then quit and reopen LongShot."
        case .screenshotFailed:
            return "macOS did not return a screenshot for the selected area."
        case .noDisplayForRegion:
            return "The selected area was not inside an active display."
        case .noImages:
            return "No images were captured."
        case .stitchFailed:
            return "The captured slices could not be stitched."
        case .saveFailed:
            return "The final image could not be saved."
        }
    }
}

struct CaptureSettings {
    var maxFrames = 36
    var settleDelay: TimeInterval = 0.42
    var scrollFraction: CGFloat = 0.72

    static let defaults = CaptureSettings()

    static func load() -> CaptureSettings {
        let defaults = UserDefaults.standard
        var settings = CaptureSettings.defaults

        let maxFrames = defaults.integer(forKey: "capture.maxFrames")
        if maxFrames > 0 {
            settings.maxFrames = maxFrames
        }

        let settleDelay = defaults.double(forKey: "capture.settleDelay")
        if settleDelay > 0 {
            settings.settleDelay = settleDelay
        }

        let scrollFraction = defaults.double(forKey: "capture.scrollFraction")
        if scrollFraction > 0 {
            settings.scrollFraction = scrollFraction
        }

        return settings
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(maxFrames, forKey: "capture.maxFrames")
        defaults.set(settleDelay, forKey: "capture.settleDelay")
        defaults.set(Double(scrollFraction), forKey: "capture.scrollFraction")
    }
}

final class CaptureManager {
    var settings = CaptureSettings.load()
    private let eventSource = CGEventSource(stateID: .hidSystemState)

    private struct DisplayContext {
        let screen: NSScreen
        let displayID: CGDirectDisplayID
        let screenFrame: CGRect
        let displayBounds: CGRect
    }

    func captureLongPage(
        region: CGRect,
        progress: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let outputURL = try self.runCapture(region: region, progress: progress)
                completion(.success(outputURL))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private func runCapture(region: CGRect, progress: @escaping (String) -> Void) throws -> URL {
        var frames: [CGImage] = []

        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.screenRecordingPermissionMissing
        }

        progress("Focusing...")
        focusSelectedRegion(region)
        Thread.sleep(forTimeInterval: 0.60)

        progress("Frame 1")
        let first = try captureRegion(region)
        frames.append(first)

        for index in 2...settings.maxFrames {
            progress("Scroll")
            scrollDown(in: region)
            Thread.sleep(forTimeInterval: settings.settleDelay)

            progress("Frame \(index)")
            let next = try captureRegion(region)

            if let previous = frames.last, ImageStitcher.isVisuallySame(previous, next) {
                progress("Bottom")
                break
            }

            frames.append(next)
        }

        guard !frames.isEmpty else { throw CaptureError.noImages }

        progress("Stitching")
        guard let stitched = ImageStitcher.stitch(frames) else {
            throw CaptureError.stitchFailed
        }

        progress("Saving")
        let outputURL = try outputURL()
        guard ImageWriter.writePNG(stitched, to: outputURL) else {
            throw CaptureError.saveFailed
        }

        return outputURL
    }

    private func captureRegion(_ region: CGRect) throws -> CGImage {
        if #available(macOS 15.2, *) {
            let candidates = screenCaptureKitRects(for: region)
            var fallbackImage: CGImage?

            for rect in candidates {
                if let image = try? captureWithScreenCaptureKit(rect: rect) {
                    if !isMostlyBlack(image) {
                        return image
                    }
                    fallbackImage = image
                }
            }

            if fallbackImage != nil {
                throw CaptureError.blankCapture
            }
        }

        guard let image = captureWithDisplayAPI(region: region) else {
            throw CaptureError.screenshotFailed
        }

        if isMostlyBlack(image) {
            throw CaptureError.blankCapture
        }

        return image
    }

    @available(macOS 15.2, *)
    private func captureWithScreenCaptureKit(rect: CGRect) throws -> CGImage {
        let semaphore = DispatchSemaphore(value: 0)
        var capturedImage: CGImage?
        var capturedError: Error?

        SCScreenshotManager.captureImage(in: rect) { image, error in
            capturedImage = image
            capturedError = error
            semaphore.signal()
        }

        semaphore.wait()

        if let capturedError {
            throw capturedError
        }

        guard let capturedImage else {
            throw CaptureError.screenshotFailed
        }

        return capturedImage
    }

    private func screenCaptureKitRects(for region: CGRect) -> [CGRect] {
        guard let context = displayContext(for: region) else {
            return [region.integral]
        }

        let displayLocal = CGRect(
            x: context.displayBounds.minX + (region.minX - context.screenFrame.minX),
            y: context.displayBounds.minY + (context.screenFrame.maxY - region.maxY),
            width: region.width,
            height: region.height
        ).integral

        return [displayLocal, region.integral]
    }

    private func captureWithDisplayAPI(region: CGRect) -> CGImage? {
        guard let context = displayContext(for: region) else {
            return nil
        }

        let displayRect = CGRect(
            x: context.displayBounds.minX + (region.minX - context.screenFrame.minX),
            y: context.displayBounds.minY + (context.screenFrame.maxY - region.maxY),
            width: region.width,
            height: region.height
        ).integral

        return CGDisplayCreateImage(context.displayID, rect: displayRect)
    }

    private func displayContext(for region: CGRect) -> DisplayContext? {
        let center = CGPoint(x: region.midX, y: region.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }),
              let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        return DisplayContext(
            screen: screen,
            displayID: displayID,
            screenFrame: screen.frame,
            displayBounds: CGDisplayBounds(displayID)
        )
    }

    private func focusSelectedRegion(_ region: CGRect) {
        let center = eventPoint(for: CGPoint(x: region.midX, y: region.midY))
        CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.10)
        CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.04)
        CGEvent(mouseEventSource: eventSource, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    private func scrollDown(in region: CGRect) {
        let center = eventPoint(for: CGPoint(x: region.midX, y: region.midY))
        CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: center, mouseButton: .left)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.04)

        let pixels = Int32(max(120, region.height * settings.scrollFraction))
        let tickCount = 4
        let tickPixels = max(1, pixels / Int32(tickCount))
        for _ in 0..<tickCount {
            CGEvent(scrollWheelEvent2Source: eventSource, units: .pixel, wheelCount: 1, wheel1: -tickPixels, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.035)
        }

        let lineTicks = Int32(max(3, min(12, Int(region.height / 90))))
        CGEvent(scrollWheelEvent2Source: eventSource, units: .line, wheelCount: 1, wheel1: -lineTicks, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    }

    private func eventPoint(for appKitPoint: CGPoint) -> CGPoint {
        let pointRect = CGRect(x: appKitPoint.x, y: appKitPoint.y, width: 1, height: 1)
        guard let context = displayContext(for: pointRect) else {
            let mainFrame = NSScreen.main?.frame ?? CGRect.zero
            return CGPoint(x: appKitPoint.x, y: mainFrame.maxY - appKitPoint.y)
        }

        return CGPoint(
            x: context.displayBounds.minX + (appKitPoint.x - context.screenFrame.minX),
            y: context.displayBounds.minY + (context.screenFrame.maxY - appKitPoint.y)
        )
    }

    private func outputURL() throws -> URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("LongShot", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return directory.appendingPathComponent("LongShot-\(formatter.string(from: Date())).png")
    }

    private func isMostlyBlack(_ image: CGImage) -> Bool {
        guard let pixels = PixelImage.make(from: image) else { return false }

        let stepX = max(1, pixels.width / 80)
        let stepY = max(1, pixels.height / 80)
        var blackCount = 0
        var sampleCount = 0

        var y = 0
        while y < pixels.height {
            var x = 0
            while x < pixels.width {
                let index = ((y * pixels.width) + x) * 4
                if index + 2 < pixels.bytes.count {
                    let r = Int(pixels.bytes[index])
                    let g = Int(pixels.bytes[index + 1])
                    let b = Int(pixels.bytes[index + 2])
                    if r + g + b < 18 {
                        blackCount += 1
                    }
                    sampleCount += 1
                }
                x += stepX
            }
            y += stepY
        }

        guard sampleCount > 0 else { return false }
        return Double(blackCount) / Double(sampleCount) > 0.98
    }
}

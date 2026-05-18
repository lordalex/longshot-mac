import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct PixelImage {
    let width: Int
    let height: Int
    let bytes: [UInt8]
    let cgImage: CGImage
}

enum ImageStitcher {
    static func stitch(_ images: [CGImage]) -> CGImage? {
        guard let first = images.first else { return nil }

        var segments: [(image: CGImage, cropTop: Int)] = [(first, 0)]
        var previous = first

        for current in images.dropFirst() {
            let overlap = bestOverlap(previous: previous, current: current)
            segments.append((current, overlap))
            previous = current
        }

        let width = images.map(\.width).min() ?? first.width
        let totalHeight = segments.reduce(0) { sum, segment in
            sum + max(0, segment.image.height - segment.cropTop)
        }

        guard width > 0, totalHeight > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .none
        var yOffset = 0

        for segment in segments {
            let cropTop = min(segment.cropTop, segment.image.height - 1)
            let cropHeight = segment.image.height - cropTop
            guard cropHeight > 0,
                  let crop = segment.image.cropping(to: CGRect(x: 0, y: cropTop, width: width, height: cropHeight)) else {
                continue
            }

            let drawY = totalHeight - yOffset - cropHeight
            context.draw(crop, in: CGRect(x: 0, y: drawY, width: width, height: cropHeight))
            yOffset += cropHeight
        }

        return context.makeImage()
    }

    static func isVisuallySame(_ lhs: CGImage, _ rhs: CGImage) -> Bool {
        guard let left = PixelImage.make(from: lhs), let right = PixelImage.make(from: rhs) else {
            return false
        }

        let width = min(left.width, right.width)
        let height = min(left.height, right.height)
        guard width > 0, height > 0 else { return false }

        let stepX = max(1, width / 64)
        let stepY = max(1, height / 64)
        var total = 0
        var count = 0

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                total += pixelDistance(left, right, x: x, yLeft: y, yRight: y)
                count += 1
                x += stepX
            }
            y += stepY
        }

        guard count > 0 else { return false }
        return Double(total) / Double(count) < 2.0
    }

    private static func bestOverlap(previous: CGImage, current: CGImage) -> Int {
        guard let previousPixels = PixelImage.make(from: previous),
              let currentPixels = PixelImage.make(from: current) else {
            return Int(Double(current.height) * 0.28)
        }

        let maxOverlap = min(previousPixels.height, currentPixels.height) * 85 / 100
        let minOverlap = max(32, min(previousPixels.height, currentPixels.height) / 12)
        guard maxOverlap > minOverlap else {
            return minOverlap
        }

        var bestOverlap = minOverlap
        var bestScore = Double.greatestFiniteMagnitude
        var overlap = minOverlap

        while overlap <= maxOverlap {
            let score = overlapScore(previous: previousPixels, current: currentPixels, overlap: overlap)
            if score < bestScore {
                bestScore = score
                bestOverlap = overlap
            }
            overlap += max(2, min(previousPixels.height, currentPixels.height) / 160)
        }

        return bestOverlap
    }

    private static func overlapScore(previous: PixelImage, current: PixelImage, overlap: Int) -> Double {
        let width = min(previous.width, current.width)
        let sampleRows = 28
        let sampleCols = 48
        let stepY = max(1, overlap / sampleRows)
        let stepX = max(1, width / sampleCols)

        var total = 0
        var count = 0
        var y = 0

        while y < overlap {
            let previousY = previous.height - overlap + y
            let currentY = y
            var x = 0
            while x < width {
                total += pixelDistance(previous, current, x: x, yLeft: previousY, yRight: currentY)
                count += 1
                x += stepX
            }
            y += stepY
        }

        guard count > 0 else { return Double.greatestFiniteMagnitude }
        return Double(total) / Double(count)
    }

    private static func pixelDistance(_ left: PixelImage, _ right: PixelImage, x: Int, yLeft: Int, yRight: Int) -> Int {
        let leftIndex = ((yLeft * left.width) + x) * 4
        let rightIndex = ((yRight * right.width) + x) * 4
        guard leftIndex + 2 < left.bytes.count, rightIndex + 2 < right.bytes.count else {
            return 255
        }

        let dr = abs(Int(left.bytes[leftIndex]) - Int(right.bytes[rightIndex]))
        let dg = abs(Int(left.bytes[leftIndex + 1]) - Int(right.bytes[rightIndex + 1]))
        let db = abs(Int(left.bytes[leftIndex + 2]) - Int(right.bytes[rightIndex + 2]))
        return dr + dg + db
    }
}

extension PixelImage {
    static func make(from image: CGImage) -> PixelImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ok = bytes.withUnsafeMutableBytes { pointer -> Bool in
            guard let baseAddress = pointer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard ok else { return nil }
        return PixelImage(width: width, height: height, bytes: bytes, cgImage: image)
    }
}

enum ImageWriter {
    static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return false
        }

        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}

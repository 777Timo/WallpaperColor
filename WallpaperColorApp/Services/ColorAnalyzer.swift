import CoreGraphics
import CryptoKit
import Foundation

struct WallpaperZones: Sendable {
    let center: String
    let top:    String
    let bottom: String
    let left:   String
    let right:  String
}

enum ColorAnalyzer {

    // MARK: - Hash (Änderungserkennung)

    nonisolated static func hash(_ image: CGImage) -> String {
        guard let pixels = rawPixels(from: image, width: 20, height: 20) else { return "" }
        let data = Data(pixels.flatMap { [$0.r, $0.g, $0.b] })
        return Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Durchschnittsfarbe

    nonisolated static func averageColor(_ image: CGImage) -> String {
        guard let pixels = rawPixels(from: image, width: 100, height: 100), !pixels.isEmpty else {
            return "#000000"
        }
        let n = pixels.count
        let r = pixels.reduce(0) { $0 + Int($1.r) } / n
        let g = pixels.reduce(0) { $0 + Int($1.g) } / n
        let b = pixels.reduce(0) { $0 + Int($1.b) } / n
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Dominante Farbe (Median-Cut, 8 Farben)

    nonisolated static func dominantColor(_ image: CGImage) -> String {
        guard let pixels = rawPixels(from: image, width: 150, height: 150), !pixels.isEmpty else {
            return "#000000"
        }
        let buckets = medianCut(pixels: pixels, numColors: 8)
        guard let largest = buckets.max(by: { $0.count < $1.count }), !largest.isEmpty else {
            return "#000000"
        }
        let n = largest.count
        let r = largest.reduce(0) { $0 + Int($1.r) } / n
        let g = largest.reduce(0) { $0 + Int($1.g) } / n
        let b = largest.reduce(0) { $0 + Int($1.b) } / n
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Farbzonen (5 Bereiche)

    nonisolated static func zoneColors(_ image: CGImage) -> WallpaperZones {
        let w = image.width
        let h = image.height

        func avg(_ rect: CGRect) -> String {
            guard let cropped = image.cropping(to: rect) else { return "#808080" }
            return averageColor(cropped)
        }

        return WallpaperZones(
            center: avg(CGRect(x: w / 4,     y: h / 4,     width: w / 2, height: h / 2)),
            top:    avg(CGRect(x: 0,          y: 0,          width: w,     height: h / 3)),
            bottom: avg(CGRect(x: 0,          y: h * 2 / 3, width: w,     height: h / 3)),
            left:   avg(CGRect(x: 0,          y: 0,          width: w / 3, height: h)),
            right:  avg(CGRect(x: w * 2 / 3, y: 0,          width: w / 3, height: h))
        )
    }

    // MARK: - Helligkeit-Emoji (⬛/⬜/🔲)

    nonisolated static func brightnessBlock(_ hex: String) -> String {
        guard hex.hasPrefix("#"), hex.count == 7,
              let value = UInt32(hex.dropFirst(), radix: 16) else { return hex }
        let r = Double((value >> 16) & 0xFF)
        let g = Double((value >> 8) & 0xFF)
        let b = Double(value & 0xFF)
        let lum = 0.299 * r + 0.587 * g + 0.114 * b
        let block = lum < 80 ? "⬛" : (lum > 200 ? "⬜" : "🔲")
        return "\(block) \(hex)"
    }

    // MARK: - Pixel-Hilfsfunktionen

    private struct RGB: Sendable {
        let r, g, b: UInt8
    }

    private static func rawPixels(from image: CGImage, width: Int, height: Int) -> [RGB]? {
        let bytesPerPixel = 4
        var data = [UInt8](repeating: 0, count: height * width * bytesPerPixel)
        guard let ctx = CGContext(
            data: &data,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var pixels: [RGB] = []
        pixels.reserveCapacity(width * height)
        for i in stride(from: 0, to: data.count, by: bytesPerPixel) {
            pixels.append(RGB(r: data[i], g: data[i + 1], b: data[i + 2]))
        }
        return pixels
    }

    // MARK: - Median-Cut Quantisierung

    private static func medianCut(pixels: [RGB], numColors: Int) -> [[RGB]] {
        var buckets: [[RGB]] = [pixels]

        while buckets.count < numColors {
            // Bucket mit größtem Farbbereich finden
            var maxRange = 0
            var splitIdx = 0
            for (i, bucket) in buckets.enumerated() {
                guard !bucket.isEmpty else { continue }
                let rRange = Int(bucket.map(\.r).max()!) - Int(bucket.map(\.r).min()!)
                let gRange = Int(bucket.map(\.g).max()!) - Int(bucket.map(\.g).min()!)
                let bRange = Int(bucket.map(\.b).max()!) - Int(bucket.map(\.b).min()!)
                let range = max(rRange, gRange, bRange)
                if range > maxRange { maxRange = range; splitIdx = i }
            }
            if maxRange == 0 { break }

            var bucket = buckets.remove(at: splitIdx)
            let rRange = Int(bucket.map(\.r).max()!) - Int(bucket.map(\.r).min()!)
            let gRange = Int(bucket.map(\.g).max()!) - Int(bucket.map(\.g).min()!)
            let bRange = Int(bucket.map(\.b).max()!) - Int(bucket.map(\.b).min()!)

            if rRange >= gRange && rRange >= bRange {
                bucket.sort { $0.r < $1.r }
            } else if gRange >= bRange {
                bucket.sort { $0.g < $1.g }
            } else {
                bucket.sort { $0.b < $1.b }
            }

            let mid = bucket.count / 2
            buckets.append(Array(bucket[..<mid]))
            buckets.append(Array(bucket[mid...]))
        }
        return buckets
    }
}

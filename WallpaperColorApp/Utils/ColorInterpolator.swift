import Foundation

enum ColorInterpolator {
    /// Linearer Übergang zwischen zwei Hex-Farben. t=0 → from, t=1 → to.
    static func lerp(_ from: String, _ to: String, t: Double) -> String {
        guard let (r1, g1, b1) = parseHex(from),
              let (r2, g2, b2) = parseHex(to) else { return to }
        let t = max(0, min(1, t))
        let r = UInt8((Double(r1) + (Double(r2) - Double(r1)) * t).rounded())
        let g = UInt8((Double(g1) + (Double(g2) - Double(g1)) * t).rounded())
        let b = UInt8((Double(b1) + (Double(b2) - Double(b1)) * t).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func parseHex(_ hex: String) -> (UInt8, UInt8, UInt8)? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let rgb = UInt64(s, radix: 16) else { return nil }
        return (UInt8((rgb >> 16) & 0xFF), UInt8((rgb >> 8) & 0xFF), UInt8(rgb & 0xFF))
    }
}

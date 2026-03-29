import AppKit
import CoreGraphics

enum WallpaperCapture {
    /// Lädt das aktuelle Wallpaper-Bild des Hauptmonitors.
    /// Primär via NSWorkspace (kein Deprecation-Problem), Fallback via Quartz-WindowCapture
    /// (funktioniert auch mit Photos-Slideshow-Wallpapers).
    nonisolated static func captureMainWallpaper() -> CGImage? {
        if let cgImage = captureViaWorkspace() { return cgImage }
        return captureViaQuartz()
    }

    // MARK: - Primary: NSWorkspace (static + most dynamic wallpapers)

    private static func captureViaWorkspace() -> CGImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let nsImage = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    // MARK: - Fallback: Quartz CGWindowListCreateImage (Photos Slideshow etc.)

    private static func captureViaQuartz() -> CGImage? {
        guard let wid = findWallpaperWindowID() else { return nil }
        return CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            wid,
            [.boundsIgnoreFraming, .nominalResolution]
        )
    }

    private static func findWallpaperWindowID() -> CGWindowID? {
        guard let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        var candidates: [(id: CGWindowID, x: CGFloat)] = []
        for window in list {
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let name  = window[kCGWindowName as String]  as? String ?? ""
            let layer = window[kCGWindowLayer as String]  as? Int    ?? 0
            guard owner == "Dock", name.contains("Wallpaper"), layer < -2_147_483_620 else { continue }
            let wid = window[kCGWindowNumber as String] as? CGWindowID ?? 0
            var bounds = CGRect.zero
            if let ref = window[kCGWindowBounds as String] as? [String: Any] {
                CGRectMakeWithDictionaryRepresentation(ref as CFDictionary, &bounds)
            }
            candidates.append((id: wid, x: bounds.origin.x))
        }
        return candidates.min(by: { $0.x < $1.x })?.id
    }
}

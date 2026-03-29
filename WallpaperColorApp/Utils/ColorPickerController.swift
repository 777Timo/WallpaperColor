import AppKit

@MainActor
final class ColorPickerController: NSObject, ObservableObject {
    @Published var pickedHex: String = "#FFFFFF"
    @Published var isOpen: Bool = false

    func open(initialHex: String) {
        pickedHex = initialHex
        isOpen = true

        let panel = NSColorPanel.shared
        if let color = NSColor(hex: initialHex) {
            panel.color = color
        }
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.isContinuous = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating

        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let pf = panel.frame
            panel.setFrameOrigin(NSPoint(
                x: sf.origin.x + (sf.width - pf.width) / 2,
                y: sf.origin.y + (sf.height - pf.height) / 2
            ))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
    }

    @objc private func colorChanged(_ sender: Any?) {
        guard let srgb = NSColorPanel.shared.color.usingColorSpace(.sRGB) else { return }
        let r = min(255, Int(srgb.redComponent * 256))
        let g = min(255, Int(srgb.greenComponent * 256))
        let b = min(255, Int(srgb.blueComponent * 256))
        pickedHex = String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7,
              let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            srgbRed:   CGFloat((value >> 16) & 0xFF) / 255,
            green:     CGFloat((value >>  8) & 0xFF) / 255,
            blue:      CGFloat( value        & 0xFF) / 255,
            alpha: 1.0
        )
    }
}

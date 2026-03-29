import SwiftUI
import AppKit

@main
struct WallpaperColorApp: App {
    @StateObject private var service = WallpaperService()
    @StateObject private var picker  = ColorPickerController()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(service)
                .environmentObject(picker)
        } label: {
            MenuBarIcon(dominantHex: service.lastDominantColor,
                        screensaverActive: service.screensaverActive,
                        screenLocked: service.screenLocked)
        }
        .menuBarExtraStyle(.menu)

        WindowGroup("Einstellungen", id: "settings") {
            SettingsView()
                .environmentObject(service)
        }
        .defaultSize(width: 440, height: 520)
        .windowResizability(.contentSize)
    }
}

/// Kleines Icon mit Farbpunkt für die aktuelle dominante Farbe.
private struct MenuBarIcon: View {
    let dominantHex: String
    let screensaverActive: Bool
    let screenLocked: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image("icon_menubar")
                .renderingMode(.original)

            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                .offset(x: 1, y: 1)
        }
    }

    private var dotColor: Color {
        if screensaverActive || screenLocked {
            return .gray.opacity(0.6)
        }
        guard let ns = NSColor(hex: dominantHex) else { return .gray.opacity(0.4) }
        return Color(nsColor: ns)
    }
}

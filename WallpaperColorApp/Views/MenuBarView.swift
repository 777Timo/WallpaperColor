import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var service: WallpaperService
    @EnvironmentObject var picker: ColorPickerController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Farbinfo (nicht klickbar)
        Button("Ø  \(ColorAnalyzer.brightnessBlock(service.lastAverageColor))") {}
            .disabled(true)
        Button("◆  \(ColorAnalyzer.brightnessBlock(service.lastDominantColor))") {}
            .disabled(true)

        Divider()

        Button(lastUpdatedText) {}
            .disabled(true)
        Button("Status: \(service.statusMessage)") {}
            .disabled(true)

        if service.screensaverActive {
            Button("Screensaver aktiv") {}
                .disabled(true)
        }
        if service.screenLocked {
            Button("Bildschirm gesperrt") {}
                .disabled(true)
        }

        Divider()

        Button("Jetzt aktualisieren") {
            service.checkNow()
        }

        Button("Farbe manuell wählen…") {
            picker.open(initialHex: service.lastDominantColor)
        }

        Button("↩  \(picker.pickedHex) senden") {
            service.sendManualColor(picker.pickedHex)
        }
        .disabled(!picker.isOpen)

        Divider()

        Button(service.isActive ? "Pausieren" : "Fortsetzen") {
            service.togglePause()
        }

        Button("Einstellungen…") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }

        Divider()

        Button("Beenden") {
            NSApp.terminate(nil)
        }
    }

    private var lastUpdatedText: String {
        guard let date = service.lastUpdated else { return "Zuletzt: —" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return "Zuletzt: \(f.string(from: date))"
    }
}

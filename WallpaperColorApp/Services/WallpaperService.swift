import Foundation
import AppKit

@MainActor
final class WallpaperService: ObservableObject {
    @Published var lastAverageColor: String  = "—"
    @Published var lastDominantColor: String = "—"
    @Published var lastUpdated: Date?        = nil
    @Published var isActive: Bool            = true
    @Published var statusMessage: String     = "Wird geladen…"
    @Published var screensaverActive: Bool   = false
    @Published var screenLocked: Bool        = false

    private var pollingTask: Task<Void, Never>?
    private var transitionTask: Task<Void, Never>?
    private var lastHash: String?
    private var lastSentAvg: String = ""
    private var lastSentDom: String = ""
    private var pausedForScreensaver = false
    private var pausedForScreenLock  = false

    init() {
        setupMonitors()
        start()
    }

    // MARK: - Steuerung

    func start() {
        isActive = true
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.check(force: true)
            while !Task.isCancelled && self.isActive {
                let interval = SettingsManager.shared.settings.pollInterval
                do { try await Task.sleep(for: .seconds(interval)) } catch { break }
                if !Task.isCancelled && self.isActive { await self.check() }
            }
        }
    }

    func stop() {
        isActive = false
        pollingTask?.cancel()
        pollingTask = nil
        transitionTask?.cancel()
        transitionTask = nil
    }

    func togglePause() {
        if isActive { stop() } else { start() }
    }

    func checkNow() {
        transitionTask?.cancel()
        transitionTask = nil
        Task { await check(force: true) }
    }

    func sendManualColor(_ hex: String) {
        Task {
            let settings = SettingsManager.shared.settings
            let ok = await doSend(avg: hex, dom: hex, zones: nil, settings: settings)
            if ok {
                lastAverageColor  = hex
                lastDominantColor = hex
                lastUpdated       = Date()
            }
        }
    }

    func applySettings(_ settings: AppSettings) {
        SettingsManager.shared.settings = settings
        if isActive { stop(); start() }
    }

    // MARK: - Monitore (Screensaver, Sperre, Wake)

    private func setupMonitors() {
        // Screensaver
        ScreensaverMonitor.shared.onScreensaverChange = { [weak self] active in
            guard let self else { return }
            self.screensaverActive = active
            let pauseOn = SettingsManager.shared.settings.pauseOnScreensaver
            if active && pauseOn {
                self.pausedForScreensaver = true
                self.stop()
            } else if !active && self.pausedForScreensaver {
                self.pausedForScreensaver = false
                self.start()
            }
        }

        // Bildschirmsperre
        ScreensaverMonitor.shared.onScreenLockChange = { [weak self] locked in
            guard let self else { return }
            self.screenLocked = locked
            let pauseOn = SettingsManager.shared.settings.pauseOnScreenLock
            if locked && pauseOn {
                self.pausedForScreenLock = true
                self.stop()
            } else if !locked && self.pausedForScreenLock {
                self.pausedForScreenLock = false
                self.start()
            }
        }

        // Wake from Sleep → sofort prüfen
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                self.checkNow()
            }
        }
    }

    // MARK: - Analyse + Senden

    private struct AnalysisResult: Sendable {
        let hash: String
        let avg: String
        let dom: String
        let zones: WallpaperZones?
    }

    private func check(force: Bool = false) async {
        let currentHash  = lastHash
        let settings     = SettingsManager.shared.settings
        let enableZones  = settings.enableZones

        let result: AnalysisResult? = await Task.detached(priority: .userInitiated) {
            guard let img = WallpaperCapture.captureMainWallpaper() else { return nil }
            let hash = ColorAnalyzer.hash(img)
            if !force && hash == currentHash { return nil }
            return AnalysisResult(
                hash:  hash,
                avg:   ColorAnalyzer.averageColor(img),
                dom:   ColorAnalyzer.dominantColor(img),
                zones: enableZones ? ColorAnalyzer.zoneColors(img) : nil
            )
        }.value

        guard let result else { return }

        transitionTask?.cancel()

        let prevAvg = lastSentAvg
        let prevDom = lastSentDom
        let newAvg  = result.avg
        let newDom  = result.dom
        let zones   = result.zones
        let hash    = result.hash

        if settings.transitionDuration > 0, !prevAvg.isEmpty, prevAvg != newAvg {
            // Sanfter Übergang in eigenem Task
            lastHash = hash  // Hash sofort merken, kein Re-Trigger
            transitionTask = Task { [weak self] in
                guard let self else { return }
                let steps     = 8
                let stepDelay = settings.transitionDuration / Double(steps)
                for step in 1...steps {
                    if Task.isCancelled { return }
                    let t    = Double(step) / Double(steps)
                    let iAvg = ColorInterpolator.lerp(prevAvg, newAvg, t: t)
                    let iDom = ColorInterpolator.lerp(prevDom, newDom, t: t)
                    let ok   = await self.doSend(avg: iAvg, dom: iDom, zones: zones, settings: settings)
                    if ok {
                        self.lastSentAvg      = iAvg
                        self.lastSentDom      = iDom
                        self.lastAverageColor  = iAvg
                        self.lastDominantColor = iDom
                    }
                    if step < steps { try? await Task.sleep(for: .seconds(stepDelay)) }
                }
                if !Task.isCancelled {
                    self.lastUpdated  = Date()
                    self.statusMessage = "aktiv"
                }
            }
        } else {
            // Direktes Senden
            let ok = await doSend(avg: newAvg, dom: newDom, zones: zones, settings: settings)
            if ok {
                lastHash          = hash
                lastSentAvg       = newAvg
                lastSentDom       = newDom
                lastAverageColor  = newAvg
                lastDominantColor = newDom
                lastUpdated       = Date()
                statusMessage     = "aktiv"
            } else {
                statusMessage = "Webhook-Fehler"
            }
        }
    }

    @discardableResult
    private func doSend(avg: String, dom: String, zones: WallpaperZones?,
                        settings: AppSettings) async -> Bool {
        let webhookOk: Bool
        if let url = settings.webhookURL {
            webhookOk = await HAWebhook.send(average: avg, dominant: dom, zones: zones, to: url)
        } else {
            webhookOk = true
        }
        if settings.mqttEnabled {
            let capturedAvg = avg, capturedDom = dom, capturedZones = zones
            Task.detached {
                await MQTTPublisher.shared.publish(average: capturedAvg, dominant: capturedDom,
                                                   zones: capturedZones, settings: settings)
            }
        }
        return webhookOk
    }
}

import Foundation

/// Überwacht Screensaver- und Bildschirmsperre-Ereignisse via DistributedNotificationCenter.
@MainActor
final class ScreensaverMonitor {
    static let shared = ScreensaverMonitor()

    private(set) var screensaverActive = false
    private(set) var screenLocked      = false

    var onScreensaverChange: ((Bool) -> Void)?
    var onScreenLockChange:  ((Bool) -> Void)?

    private init() {
        let dc = DistributedNotificationCenter.default()
        let q  = OperationQueue.main

        dc.addObserver(forName: .init("com.apple.screensaver.didstart"), object: nil, queue: q) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handle(screensaver: true) }
        }
        dc.addObserver(forName: .init("com.apple.screensaver.didstop"), object: nil, queue: q) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handle(screensaver: false) }
        }
        dc.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: q) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handle(locked: true) }
        }
        dc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: q) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handle(locked: false) }
        }
    }

    private func handle(screensaver active: Bool) {
        screensaverActive = active
        onScreensaverChange?(active)
    }

    private func handle(locked: Bool) {
        screenLocked = locked
        onScreenLockChange?(locked)
    }
}

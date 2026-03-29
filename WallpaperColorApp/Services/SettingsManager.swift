import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var haHost: String      = "homeassistant.local:8123"
    var webhookID: String   = ""
    var pollInterval: Int   = 15

    // MQTT
    var mqttEnabled: Bool    = false
    var mqttHost: String     = "homeassistant.local"
    var mqttPort: Int        = 1883
    var mqttUsername: String = ""
    var mqttPassword: String = ""
    var mqttTopic: String    = "wallpaper/color"

    // Verhalten
    var pauseOnScreensaver:   Bool   = false
    var pauseOnScreenLock:    Bool   = false
    var transitionDuration:   Double = 0.0   // 0 = aus
    var enableZones:          Bool   = false

    enum CodingKeys: String, CodingKey {
        case haHost             = "ha_host"
        case webhookID          = "webhook_id"
        case pollInterval       = "poll_interval"
        case mqttEnabled        = "mqtt_enabled"
        case mqttHost           = "mqtt_host"
        case mqttPort           = "mqtt_port"
        case mqttUsername       = "mqtt_username"
        case mqttPassword       = "mqtt_password"
        case mqttTopic          = "mqtt_topic"
        case pauseOnScreensaver = "pause_on_screensaver"
        case pauseOnScreenLock  = "pause_on_screen_lock"
        case transitionDuration = "transition_duration"
        case enableZones        = "enable_zones"
    }

    var webhookURL: URL? {
        let id = webhookID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return nil }
        var host = haHost.trimmingCharacters(in: .whitespaces)
        if !host.hasPrefix("http") { host = "http://\(host)" }
        return URL(string: "\(host)/api/webhook/\(id)")
    }
}

@MainActor
final class SettingsManager {
    static let shared = SettingsManager()

    private let fileURL: URL
    var settings: AppSettings {
        didSet { save() }
    }

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WallpaperColor")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("settings.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: fileURL)
        }
    }
}

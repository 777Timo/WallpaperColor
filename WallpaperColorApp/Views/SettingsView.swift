import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var service: WallpaperService

    // Home Assistant
    @State private var haHost: String    = ""
    @State private var webhookID: String = ""
    @State private var pollInterval: Int = 15

    // MQTT
    @State private var mqttEnabled: Bool    = false
    @State private var mqttHost: String     = ""
    @State private var mqttPort: Int        = 1883
    @State private var mqttTopic: String    = ""
    @State private var mqttUsername: String = ""
    @State private var mqttPassword: String = ""

    // Verhalten
    @State private var pauseOnScreensaver: Bool   = false
    @State private var pauseOnScreenLock: Bool    = false
    @State private var transitionDuration: Double = 0.0
    @State private var enableZones: Bool          = false
    @State private var launchAtLogin: Bool        = false

    var body: some View {
        Form {
            Section("Home Assistant") {
                TextField("Host (z.B. homeassistant.local:8123)", text: $haHost)
                TextField("Webhook-ID", text: $webhookID)
                Text("Webhook muss in HA als Automation mit diesem Trigger-Namen angelegt sein.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("MQTT") {
                Toggle("MQTT aktivieren", isOn: $mqttEnabled)
                if mqttEnabled {
                    TextField("Broker-Host", text: $mqttHost)
                    HStack {
                        Text("Port")
                        TextField("1883", value: $mqttPort, format: .number)
                            .frame(width: 70)
                        Spacer()
                    }
                    TextField("Topic", text: $mqttTopic)
                    TextField("Benutzername (optional)", text: $mqttUsername)
                    SecureField("Passwort (optional)", text: $mqttPassword)
                }
            }

            Section("Polling") {
                Stepper("Interval: \(pollInterval) Sekunden", value: $pollInterval, in: 5...300, step: 5)
            }

            Section("Farbübergang") {
                Toggle("Sanfter Übergang aktivieren", isOn: Binding(
                    get: { transitionDuration > 0 },
                    set: { transitionDuration = $0 ? 1.5 : 0 }
                ))
                if transitionDuration > 0 {
                    HStack {
                        Text("Dauer: \(transitionDuration, specifier: "%.1f") s")
                        Slider(value: $transitionDuration, in: 0.5...5.0, step: 0.5)
                    }
                }
            }

            Section("Farbzonen") {
                Toggle("5-Zonen-Analyse (Mitte / Oben / Unten / Links / Rechts)", isOn: $enableZones)
                if enableZones {
                    Text("Zusätzliche Felder im Webhook & MQTT: zone_mitte, zone_oben, zone_unten, zone_links, zone_rechts")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Verhalten") {
                Toggle("Bei Screensaver pausieren",   isOn: $pauseOnScreensaver)
                Toggle("Bei Bildschirmsperre pausieren", isOn: $pauseOnScreenLock)
                Toggle("Bei Anmeldung starten",       isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin, perform: { val in
                        LaunchAtLoginManager.shared.setEnabled(val)
                    })
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: dynamicHeight)
        .animation(.default, value: mqttEnabled)
        .animation(.default, value: transitionDuration > 0)
        .animation(.default, value: enableZones)
        .onAppear { load() }
        .onChange(of: haHost,             perform: { _ in save() })
        .onChange(of: webhookID,          perform: { _ in save() })
        .onChange(of: pollInterval,       perform: { _ in save() })
        .onChange(of: mqttEnabled,        perform: { _ in save() })
        .onChange(of: mqttHost,           perform: { _ in save() })
        .onChange(of: mqttPort,           perform: { _ in save() })
        .onChange(of: mqttTopic,          perform: { _ in save() })
        .onChange(of: mqttUsername,       perform: { _ in save() })
        .onChange(of: mqttPassword,       perform: { _ in save() })
        .onChange(of: pauseOnScreensaver, perform: { _ in save() })
        .onChange(of: pauseOnScreenLock,  perform: { _ in save() })
        .onChange(of: transitionDuration, perform: { _ in save() })
        .onChange(of: enableZones,        perform: { _ in save() })
    }

    private var dynamicHeight: CGFloat {
        var h: CGFloat = 520
        if mqttEnabled    { h += 130 }
        if transitionDuration > 0 { h += 30 }
        if enableZones    { h += 30 }
        return h
    }

    private func load() {
        let s          = SettingsManager.shared.settings
        haHost         = s.haHost
        webhookID      = s.webhookID
        pollInterval   = s.pollInterval
        mqttEnabled    = s.mqttEnabled
        mqttHost       = s.mqttHost
        mqttPort       = s.mqttPort
        mqttTopic      = s.mqttTopic
        mqttUsername   = s.mqttUsername
        mqttPassword   = s.mqttPassword
        pauseOnScreensaver = s.pauseOnScreensaver
        pauseOnScreenLock  = s.pauseOnScreenLock
        transitionDuration = s.transitionDuration
        enableZones    = s.enableZones
        launchAtLogin  = LaunchAtLoginManager.shared.isEnabled
    }

    private func save() {
        service.applySettings(AppSettings(
            haHost:             haHost,
            webhookID:          webhookID,
            pollInterval:       pollInterval,
            mqttEnabled:        mqttEnabled,
            mqttHost:           mqttHost,
            mqttPort:           mqttPort,
            mqttUsername:       mqttUsername,
            mqttPassword:       mqttPassword,
            mqttTopic:          mqttTopic,
            pauseOnScreensaver: pauseOnScreensaver,
            pauseOnScreenLock:  pauseOnScreenLock,
            transitionDuration: transitionDuration,
            enableZones:        enableZones
        ))
    }
}

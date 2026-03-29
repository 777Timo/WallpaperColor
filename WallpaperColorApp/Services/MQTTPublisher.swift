import Foundation
import Network

private final class SendOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var executed = false
    func run(_ body: () -> Void) {
        lock.lock()
        guard !executed else { lock.unlock(); return }
        executed = true
        lock.unlock()
        body()
    }
}

actor MQTTPublisher {
    nonisolated static let shared = MQTTPublisher()
    private init() {}

    func publish(average: String, dominant: String,
                 zones: WallpaperZones? = nil,
                 settings: AppSettings) async {
        guard settings.mqttEnabled, !settings.mqttHost.isEmpty else { return }
        guard let port = NWEndpoint.Port(rawValue: UInt16(settings.mqttPort)) else { return }

        let username = settings.mqttUsername.isEmpty ? nil : settings.mqttUsername
        let password = settings.mqttPassword.isEmpty ? nil : settings.mqttPassword
        let topic    = settings.mqttTopic.isEmpty ? "wallpaper/color" : settings.mqttTopic

        var payload = #"{"average":"\#(average)","dominant":"\#(dominant)""#
        if let z = zones {
            payload += #","zone_center":"\#(z.center)","zone_top":"\#(z.top)","zone_bottom":"\#(z.bottom)","zone_left":"\#(z.left)","zone_right":"\#(z.right)""#
        }
        payload += "}"

        await send(host: settings.mqttHost, port: port,
                   username: username, password: password,
                   topic: topic, payload: payload)
    }

    // MARK: - Verbindung

    private func send(host: String, port: NWEndpoint.Port,
                      username: String?, password: String?,
                      topic: String, payload: String) async {

        let connectPkt = Self.buildConnect(
            clientID: "wallpaper-\(UInt32.random(in: 0...UInt32.max))",
            username: username, password: password
        )
        let publishPkt = Self.buildPublish(topic: topic, payload: payload)
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let once = SendOnce()
            let finish: @Sendable () -> Void = {
                once.run { connection.cancel(); cont.resume() }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: connectPkt, completion: .contentProcessed { _ in
                        connection.receive(minimumIncompleteLength: 2, maximumLength: 16) { _, _, _, _ in
                            connection.send(content: publishPkt, completion: .contentProcessed { _ in
                                finish()
                            })
                        }
                    })
                case .failed, .cancelled: finish()
                default: break
                }
            }
            connection.start(queue: .global(qos: .utility))
            Task { try? await Task.sleep(for: .seconds(5)); finish() }
        }
    }

    // MARK: - MQTT 3.1.1 Paketbau

    private static func buildConnect(clientID: String, username: String?, password: String?) -> Data {
        var flags: UInt8 = 0x02
        if username != nil { flags |= 0x80 }
        if password != nil { flags |= 0x40 }
        var vh = mqttString("MQTT") + Data([0x04, flags, 0x00, 0x3C])
        var pld = mqttString(clientID)
        if let u = username { pld += mqttString(u) }
        if let p = password { pld += mqttString(p) }
        return buildPacket(type: 0x10, header: vh, payload: pld)
    }

    private static func buildPublish(topic: String, payload: String) -> Data {
        buildPacket(type: 0x30, header: mqttString(topic),
                    payload: payload.data(using: .utf8) ?? Data())
    }

    private static func buildPacket(type: UInt8, header: Data, payload: Data) -> Data {
        var p = Data([type]) + encodeLength(header.count + payload.count)
        p += header; p += payload; return p
    }

    private static func mqttString(_ s: String) -> Data {
        let b = Array(s.utf8)
        return Data([UInt8(b.count >> 8), UInt8(b.count & 0xFF)] + b)
    }

    private static func encodeLength(_ length: Int) -> Data {
        var data = Data(); var rem = length
        repeat {
            var byte = UInt8(rem & 0x7F); rem >>= 7
            if rem > 0 { byte |= 0x80 }
            data.append(byte)
        } while rem > 0
        return data
    }
}

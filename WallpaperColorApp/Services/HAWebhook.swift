import Foundation

enum HAWebhook {
    nonisolated static func send(
        average: String,
        dominant: String,
        zones: WallpaperZones? = nil,
        to url: URL?
    ) async -> Bool {
        guard let url else { return false }

        var body: [String: String] = [
            "wallpaper_farbe_durchschnitt": average,
            "wallpaper_farbe_dominant":     dominant
        ]
        if let z = zones {
            body["zone_mitte"]  = z.center
            body["zone_oben"]   = z.top
            body["zone_unten"]  = z.bottom
            body["zone_links"]  = z.left
            body["zone_rechts"] = z.right
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return [200, 201, 204].contains(code)
        } catch {
            return false
        }
    }
}

import Foundation

struct ChatFrame: Codable {
    let v: Int = 1                
    let from: String
    let text: String
    let ts: TimeInterval
    let lat: Double?              
    let lon: Double?
    let acc: Double?

    static func make(
        text: String,
        from id: String,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) -> ChatFrame {
        let c = LocationProvider.currentCoordinate
        return ChatFrame(
            from: id,
            text: text,
            ts: timestamp,
            lat: c.lat,
            lon: c.lon,
            acc: c.acc
        )
    }

    private enum CodingKeys: String, CodingKey { case from, text, ts, lat, lon, acc }
}

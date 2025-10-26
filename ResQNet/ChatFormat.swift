import Foundation

enum ChatFormat {
    static func line(from frame: ChatFrame) -> String {
        let time = Date(timeIntervalSince1970: frame.ts)
            .formatted(date: .omitted, time: .standard)
        var s = "[\(time)] \(frame.text)"
        if let la = frame.lat, let lo = frame.lon {
            s += "  @\(String(format: "%.5f", la)),\(String(format: "%.5f", lo))"
            if let a = frame.acc { s += " ±\(Int(a))m" }
        }
        return s
    }
}

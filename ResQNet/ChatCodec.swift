import Foundation
import UIKit


// Lokale, stabile Geräte-ID (persistiert)
enum LocalID {
    static let value: String = {
        if let s = UserDefaults.standard.string(forKey: "local_id") { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: "local_id")
        return s
    }()
}


// Codec-Helfer
enum ChatCodec {
    static func encode(_ f: ChatFrame) -> Data? {
        try? JSONEncoder().encode(f)
    }
    static func decode(_ data: Data) -> ChatFrame? {
        try? JSONDecoder().decode(ChatFrame.self, from: data)
    }
}



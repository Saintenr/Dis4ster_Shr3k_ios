import Foundation
import UIKit

enum LocalID {
    static let value: String = {
        if let s = UserDefaults.standard.string(forKey: "local_id") { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: "local_id")
        return s
    }()
}

enum ChatCodec {
    static func encode(_ f: ChatFrame) -> Data? {
        try? JSONEncoder().encode(f)
    }
    static func decode(_ data: Data) -> ChatFrame? {
        try? JSONDecoder().decode(ChatFrame.self, from: data)
    }
}



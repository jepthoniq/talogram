import Foundation

public struct JokerQuickReply: Codable, Equatable {
    public let id: String
    public let text: String

    public init(id: String, text: String) {
        self.id = id
        self.text = text
    }

    public static func ==(lhs: JokerQuickReply, rhs: JokerQuickReply) -> Bool {
        return lhs.id == rhs.id && lhs.text == rhs.text
    }
}

public enum JokerLocalFeatureKeys {
    public static let quickReplies = "joker_quick_replies_json"
}

public func getJokerLocalQuickReplies() -> [JokerQuickReply] {
    guard let data = UserDefaults.standard.data(forKey: JokerLocalFeatureKeys.quickReplies) else {
        return []
    }
    return (try? JSONDecoder().decode([JokerQuickReply].self, from: data)) ?? []
}

public func saveJokerLocalQuickReplies(_ replies: [JokerQuickReply]) {
    let data = try? JSONEncoder().encode(replies)
    UserDefaults.standard.set(data, forKey: JokerLocalFeatureKeys.quickReplies)
    UserDefaults.standard.synchronize()
}

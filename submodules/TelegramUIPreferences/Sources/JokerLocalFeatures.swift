import Foundation

public struct JokerQuickReplyMedia: Codable, Equatable {
    public let fileName: String
    public let isVideo: Bool
    public let width: Int32
    public let height: Int32
    public let duration: Double
    public let mimeType: String

    public init(fileName: String, isVideo: Bool, width: Int32, height: Int32, duration: Double, mimeType: String) {
        self.fileName = fileName
        self.isVideo = isVideo
        self.width = width
        self.height = height
        self.duration = duration
        self.mimeType = mimeType
    }

    public static func ==(lhs: JokerQuickReplyMedia, rhs: JokerQuickReplyMedia) -> Bool {
        return lhs.fileName == rhs.fileName && lhs.isVideo == rhs.isVideo && lhs.width == rhs.width && lhs.height == rhs.height && lhs.duration == rhs.duration && lhs.mimeType == rhs.mimeType
    }
}

public struct JokerQuickReply: Codable, Equatable {
    public let id: String
    public var text: String
    public var shortcut: String?
    public var media: JokerQuickReplyMedia?

    public init(id: String, text: String, shortcut: String? = nil, media: JokerQuickReplyMedia? = nil) {
        self.id = id
        self.text = text
        self.shortcut = shortcut
        self.media = media
    }

    public static func ==(lhs: JokerQuickReply, rhs: JokerQuickReply) -> Bool {
        return lhs.id == rhs.id && lhs.text == rhs.text && lhs.shortcut == rhs.shortcut && lhs.media == rhs.media
    }
}

public enum JokerLocalFeatureKeys {
    public static let quickReplies = "joker_quick_replies_json"
}

public func jokerQuickReplyMediaDirectory() -> URL {
    let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let directoryURL = baseURL.appendingPathComponent("JokerQuickReplies", isDirectory: true)
    if !FileManager.default.fileExists(atPath: directoryURL.path) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
    }
    return directoryURL
}

public func jokerQuickReplyMediaURL(fileName: String) -> URL {
    return jokerQuickReplyMediaDirectory().appendingPathComponent(fileName)
}

public func jokerNormalizedQuickReplyShortcut(_ value: String) -> String {
    var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
    while result.hasPrefix("/") {
        result.removeFirst()
    }
    result = result.replacingOccurrences(of: " ", with: "")
    result = result.replacingOccurrences(of: "\n", with: "")
    result = result.replacingOccurrences(of: "\t", with: "")
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
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

public func jokerLocalQuickReply(matchingShortcut text: String) -> JokerQuickReply? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("/") else {
        return nil
    }
    let shortcut = jokerNormalizedQuickReplyShortcut(trimmed)
    guard !shortcut.isEmpty else {
        return nil
    }
    return getJokerLocalQuickReplies().first(where: { reply in
        guard let storedShortcut = reply.shortcut else {
            return false
        }
        return jokerNormalizedQuickReplyShortcut(storedShortcut).lowercased() == shortcut.lowercased()
    })
}

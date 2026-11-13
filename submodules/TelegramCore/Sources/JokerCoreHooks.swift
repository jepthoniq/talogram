import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit


public extension Notification.Name {
    // Posted whenever the cached subscription flag changes. TelegramUI uses it
    // to disable every Joker toggle the moment the user leaves the channel.
    static let jokerChannelSubscriptionDidChange = Notification.Name("JokerChannelSubscriptionDidChange")
}

public enum JokerCoreHooks {
    private static let subscriptionKey = "joker_channel_subscribed"

    // Every feature flag that is mirrored into UserDefaults by
    // `updateJokerSettingsInteractively` in TelegramUIPreferences.
    private static let featureFlagKeys = [
        "joker_auto_save_media",
        "joker_allow_100_accounts",
        "joker_ghost_mode",
        "joker_force_premium_translation",
        "joker_keep_deleted_messages",
        "joker_freeze_last_seen",
        "joker_bypass_copy_protection",
        "joker_story_stealth",
        "joker_call_recording",
        "joker_voice_to_text",
        "joker_secret_chat_tools"
    ]

    private static func boolFlag(_ key: String, defaultOnIfUnset: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultOnIfUnset
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    // Joker Mod: the single access gate for every Joker feature. A feature may
    // only be used while the account is a member of the required channel.
    public static func isAccessGranted() -> Bool {
        if !requireSubscriptionGateEnabled() {
            return true
        }
        return isChannelSubscribed()
    }

    public static func bypassCopyProtectionEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_bypass_copy_protection")
    }

    // Joker Mod: master switch for the secret chat tools (save media, forward
    // as a local copy, screenshot suppression). Defaults to on.
    public static func secretChatToolsEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_secret_chat_tools", defaultOnIfUnset: true)
    }

    public static func freezeLastSeenEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_freeze_last_seen")
    }

    public static func keepDeletedMessagesEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_keep_deleted_messages")
    }

    public static func autoSaveMediaEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_auto_save_media")
    }

    public static func ghostModeEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_ghost_mode")
    }

    public static func storyStealthModeEnabled() -> Bool {
        return isAccessGranted() && boolFlag("joker_story_stealth")
    }

    public static func requireSubscriptionGateEnabled() -> Bool {
        return boolFlag("joker_require_subscription", defaultOnIfUnset: true)
    }

    public static func isChannelSubscribed() -> Bool {
        return boolFlag(subscriptionKey)
    }

    public static let subscriptionChannelUsername = "aljokeruserbot"

    public static func isSubscriptionChannel(_ peer: Peer) -> Bool {
        guard let channel = peer as? TelegramChannel else {
            return false
        }
        let target = subscriptionChannelUsername.lowercased()
        if let username = channel.username, username.lowercased() == target {
            return true
        }
        for username in channel.usernames {
            if username.username.lowercased() == target {
                return true
            }
        }
        return false
    }

    private static func setAllFeatureFlags(_ value: Bool) {
        for key in featureFlagKeys {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    // Joker Mod: called as soon as the user leaves the required channel. The
    // cached membership is dropped and every feature is switched off, so the
    // compiled checks stop working immediately, not on the next refresh tick.
    public static func clearSubscriptionStatus() {
        UserDefaults.standard.set(false, forKey: subscriptionKey)
        setAllFeatureFlags(false)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .jokerChannelSubscriptionDidChange, object: nil)
    }

    public static func checkChannelSubscription(network: Network, username: String) -> Signal<Bool, NoError> {
        var normalizedName = username
        if normalizedName.hasPrefix("@") {
            normalizedName.removeFirst()
        }
        let cachedStatus = isChannelSubscribed()
        return network.request(Api.functions.contacts.resolveUsername(flags: 0, username: normalizedName, referer: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.contacts.ResolvedPeer?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Bool, NoError> in
            guard let result = result, case let .resolvedPeer(resolvedPeerData) = result else {
                return .single(cachedStatus)
            }
            let channels: [Api.InputChannel] = resolvedPeerData.chats.compactMap { chat -> Api.InputChannel? in
                guard let peer = parseTelegramGroupOrChannel(chat: chat) else {
                    return nil
                }
                return apiInputChannel(peer)
            }
            guard let inputChannel = channels.first else {
                return .single(false)
            }
            return network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
            |> map { result -> Bool in
                switch result {
                case let .channelParticipant(channelParticipantData):
                    switch channelParticipantData.participant {
                    case .channelParticipantLeft:
                        return false
                    case let .channelParticipantBanned(bannedData):
                        let hasLeft = (bannedData.flags & (1 << 0)) != 0
                        return !hasLeft
                    default:
                        return true
                    }
                }
            }
            |> `catch` { error -> Signal<Bool, NoError> in
                if error.errorCode == 400 || error.errorCode == 403 {
                    return .single(false)
                }
                return .single(cachedStatus)
            }
        }
    }

    public static func refreshChannelSubscription(network: Network) -> Signal<Void, NoError> {
        guard requireSubscriptionGateEnabled() else {
            return .complete()
        }
        return checkChannelSubscription(network: network, username: subscriptionChannelUsername)
        |> map { isSubscribed -> Void in
            let previousValue = UserDefaults.standard.object(forKey: subscriptionKey) as? Bool
            UserDefaults.standard.set(isSubscribed, forKey: subscriptionKey)
            if !isSubscribed {
                setAllFeatureFlags(false)
            }
            UserDefaults.standard.synchronize()
            if previousValue != isSubscribed {
                NotificationCenter.default.post(name: .jokerChannelSubscriptionDidChange, object: nil)
            }
            return ()
        }
    }

    public static func markMessagesAsReadViaNetwork(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
        guard !messageIds.isEmpty else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> [(Api.InputPeer, [Int32], Api.InputChannel?, Bool)] in
            var groupedIds: [PeerId: [Int32]] = [:]
            for messageId in messageIds {
                groupedIds[messageId.peerId, default: []].append(messageId.id)
            }
            var result: [(Api.InputPeer, [Int32], Api.InputChannel?, Bool)] = []
            for (peerId, ids) in groupedIds {
                guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                    continue
                }
                if peer is TelegramChannel {
                    result.append((inputPeer, ids, apiInputChannel(peer), true))
                } else {
                    result.append((inputPeer, ids, nil, false))
                }
            }
            return result
        }
        |> mapToSignal { groups -> Signal<Void, NoError> in
            var requests: [Signal<Void, NoError>] = []
            for group in groups {
                let (inputPeer, ids, inputChannel, isChannel) = group
                _ = inputPeer
                if isChannel, let inputChannel = inputChannel {
                    requests.append(account.network.request(Api.functions.channels.readMessageContents(channel: inputChannel, id: ids))
                    |> map { _ -> Void in
                        return ()
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        return .complete()
                    })
                } else {
                    requests.append(account.network.request(Api.functions.messages.readMessageContents(id: ids))
                    |> map { _ -> Void in
                        return ()
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        return .complete()
                    })
                }
            }
            return requests.reduce(Signal<Void, NoError>.complete()) { $0 |> then($1) }
        }
    }

    public static func readAllMessagesForPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputChannel?)? in
            guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                return (inputPeer, apiInputChannel(peer))
            }
            return (inputPeer, nil)
        }
        |> mapToSignal { resolved -> Signal<Void, NoError> in
            guard let (inputPeer, inputChannel) = resolved else {
                return .complete()
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel, let inputChannel = inputChannel {
                return account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: Int32.max - 1))
                |> map { _ -> Void in
                    return ()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                return account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: Int32.max - 1))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result, case let .affectedMessages(affectedMessagesData) = result {
                        account.stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                    return .complete()
                }
            }
            return .complete()
        }
    }

    public static func readMessagesUpToViaNetwork(account: Account, peerId: PeerId, maxMessageId: Int32) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputChannel?)? in
            guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                return (inputPeer, apiInputChannel(peer))
            }
            return (inputPeer, nil)
        }
        |> mapToSignal { resolved -> Signal<Void, NoError> in
            guard let (inputPeer, inputChannel) = resolved else {
                return .complete()
            }
            if peerId.namespace == Namespaces.Peer.CloudChannel, let inputChannel = inputChannel {
                return account.network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxMessageId))
                |> map { _ -> Void in
                    return ()
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
            } else if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                return account.network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxMessageId))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    if let result = result, case let .affectedMessages(affectedMessagesData) = result {
                        account.stateManager.addUpdateGroups([.updatePts(pts: affectedMessagesData.pts, ptsCount: affectedMessagesData.ptsCount)])
                    }
                    return .complete()
                }
            }
            return .complete()
        }
    }

    private static let autoSavedMessageIdsKey = "joker_auto_saved_message_ids"

    private static func autoSavedMessageKey(_ messageId: MessageId) -> String {
        return "\(messageId.namespace):\(messageId.id):\(messageId.peerId.id._internalGetInt64Value())"
    }

    private static func isAlreadyAutoSaved(messageId: MessageId) -> Bool {
        let ids = (UserDefaults.standard.array(forKey: autoSavedMessageIdsKey) as? [String]) ?? []
        return ids.contains(autoSavedMessageKey(messageId))
    }

    private static func markAutoSaved(messageId: MessageId) {
        var ids = (UserDefaults.standard.array(forKey: autoSavedMessageIdsKey) as? [String]) ?? []
        let key = autoSavedMessageKey(messageId)
        if !ids.contains(key) {
            ids.append(key)
            if ids.count > 5000 {
                ids = Array(ids.suffix(5000))
            }
            UserDefaults.standard.set(ids, forKey: autoSavedMessageIdsKey)
            UserDefaults.standard.synchronize()
        }
    }

    public static func saveConsumedMediaIfNeeded(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
        guard autoSaveMediaEnabled() else {
            return .complete()
        }
        if messageId.peerId == account.peerId {
            return .complete()
        }
        struct SavedMediaItem {
            var resource: TelegramMediaResource
            var isImage: Bool
            var width: Int32
            var height: Int32
            var mimeType: String
            var fileName: String?
            var attributes: [TelegramMediaFileAttribute]
        }
        return account.postbox.transaction { transaction -> (media: SavedMediaItem, caption: String, entities: [MessageTextEntity])? in
            guard let message = transaction.getMessage(messageId), message.flags.contains(.Incoming) else {
                return nil
            }
            if isAlreadyAutoSaved(messageId: messageId) {
                return nil
            }
            var isSelfDestruct = false
            for attribute in message.attributes {
                if let consumable = attribute as? ConsumableContentMessageAttribute, !consumable.consumed {
                    isSelfDestruct = true
                    break
                }
                if let autoclear = attribute as? AutoclearTimeoutMessageAttribute, autoclear.countdownBeginTime == nil || autoclear.countdownBeginTime == 0 {
                    isSelfDestruct = true
                    break
                }
            }
            guard isSelfDestruct else {
                return nil
            }
            markAutoSaved(messageId: messageId)
            let caption = message.text
            var entities: [MessageTextEntity] = []
            if let entitiesAttribute = message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute {
                entities = entitiesAttribute.entities
            }
            for media in message.media {
                if let image = media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                    return (SavedMediaItem(resource: largest.resource, isImage: true, width: largest.dimensions.width, height: largest.dimensions.height, mimeType: "image/jpeg", fileName: nil, attributes: []), caption, entities)
                } else if let file = media as? TelegramMediaFile {
                    return (SavedMediaItem(resource: file.resource, isImage: false, width: 0, height: 0, mimeType: file.mimeType, fileName: file.fileName, attributes: file.attributes), caption, entities)
                }
            }
            return nil
        }
        |> mapToSignal { item -> Signal<Void, NoError> in
            guard let item = item else {
                return .complete()
            }
            return account.postbox.mediaBox.resourceData(item.media.resource, option: .complete(waitUntilFetchStatus: true))
            |> take(1)
            |> mapToSignal { data -> Signal<Void, NoError> in
                guard data.complete, let bytes = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                    return .complete()
                }
                let peerId = account.peerId
                let auxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { _, _, _, _ in
                    return nil
                }, fetchResourceMediaReferenceHash: { _ in
                    return .single(nil)
                }, prepareSecretThumbnailData: { _ in
                    return nil
                }, backgroundUpload: { _, _, _ in
                    return .single(nil)
                })
                let text = StandaloneSendEnqueueMessage.Text(string: item.caption, entities: item.entities)
                let upload: Signal<StandaloneUploadMediaEvent, StandaloneUploadMediaError>
                if item.media.isImage {
                    upload = standaloneUploadedImage(postbox: account.postbox, network: account.network, peerId: peerId, text: "", source: .data(bytes), thumbnailData: nil, dimensions: PixelDimensions(width: item.media.width, height: item.media.height))
                } else {
                    upload = standaloneUploadedFile(postbox: account.postbox, network: account.network, peerId: peerId, text: "", source: .data(bytes), thumbnailData: nil, mimeType: item.media.mimeType, attributes: item.media.attributes, hintFileIsLarge: bytes.count > 10 * 1024 * 1024)
                }
                return upload
                |> `catch` { _ -> Signal<StandaloneUploadMediaEvent, NoError> in
                    return .complete()
                }
                |> mapToSignal { event -> Signal<Void, NoError> in
                    guard case let .result(result) = event, case let .media(reference) = result else {
                        return .complete()
                    }
                    let message = StandaloneSendEnqueueMessage(content: .arbitraryMedia(media: reference, text: text), replyToMessageId: nil)
                    return standaloneSendEnqueueMessages(accountPeerId: peerId, postbox: account.postbox, network: account.network, stateManager: account.stateManager, auxiliaryMethods: auxiliaryMethods, peerId: peerId, threadId: nil, messages: [message])
                    |> `catch` { _ -> Signal<StandaloneSendMessageStatus, NoError> in
                        return .complete()
                    }
                    |> map { _ in }
                }
            }
        }
    }

    public static func markStoryViewedIgnoringStealth(account: Account, peerId: PeerId, storyId: Int32) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Void, NoError> in
            guard let inputPeer = inputPeer else {
                return .complete()
            }
            return account.network.request(Api.functions.stories.readStories(peer: inputPeer, maxId: storyId))
            |> map { _ -> Void in
                return ()
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .complete()
            }
        }
    }

    private static let keptDeletedStorageKey = "joker_kept_deleted_ids"

    public static func recordKeptDeletedMessages(_ messageIds: [MessageId]) {
        guard keepDeletedMessagesEnabled(), !messageIds.isEmpty else {
            return
        }
        var storage = UserDefaults.standard.dictionary(forKey: keptDeletedStorageKey) as? [String: [Int64]] ?? [:]
        for messageId in messageIds {
            let key = String(messageId.peerId.id._internalGetInt64Value())
            var values = storage[key] ?? []
            let packed = Int64(messageId.namespace) << 32 | Int64(UInt32(bitPattern: messageId.id))
            if !values.contains(packed) {
                values.append(packed)
            }
            storage[key] = values
        }
        UserDefaults.standard.set(storage, forKey: keptDeletedStorageKey)
        UserDefaults.standard.synchronize()
    }

    public static func isKeptDeletedMessage(peerId: PeerId, namespace: Int32, id: Int32) -> Bool {
        let storage = UserDefaults.standard.dictionary(forKey: keptDeletedStorageKey) as? [String: [Int64]] ?? [:]
        guard let values = storage[String(peerId.id._internalGetInt64Value())] else {
            return false
        }
        let packed = Int64(namespace) << 32 | Int64(UInt32(bitPattern: id))
        return values.contains(packed)
    }
}

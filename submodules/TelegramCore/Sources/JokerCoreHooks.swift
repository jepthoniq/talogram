import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

// MARK: - Joker Core Hooks
// ظ†ظ‚ط§ط· ط§ظ„ط±ط¨ط· ط§ظ„ظ…ط¹ط²ظˆظ„ط© ط¯ط§ط®ظ„ ظ†ظˆط§ط© TelegramCore ظ„ط¬ظ…ظٹط¹ ظ…ظ…ظٹط²ط§طھ طھط¹ط¯ظٹظ„ط§طھ ط§ظ„ط¬ظˆظƒط± (Talogram)
// طھطھظ… ظ‚ط±ط§ط،ط© ط§ظ„ط£ط¹ظ„ط§ظ… ظ…ظ† ظ…ط±ط§ظٹط§ UserDefaults ط§ظ„طھظٹ طھظƒطھط¨ظ‡ط§ updateJokerSettingsInteractively.
// ظ…ظ„ط§ط­ط¸ط©: ط¬ظ…ظٹط¹ ط§ظ„ط¯ظˆط§ظ„ ظٹط¬ط¨ ط£ظ† طھط¨ظ‚ظ‰ ط¢ظ…ظ†ط© ظ…ظ† ط­ظٹط« ط§ظ„ظ‚ظپظ„ (ط¨ط¯ظˆظ† ط¥ظ…ظƒط§ظ†ظٹط© طھط³ط¨ط¨ ط­ظ„ظ‚ط§طھ).

public enum JokerCoreHooks {
    private static func boolFlag(_ key: String, defaultOnIfUnset: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultOnIfUnset
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    // ظ…ظٹط²ط©: طھط¬ط§ظˆط² ط­ظ…ط§ظٹط© ط§ظ„ظ†ط³ط® ظپظٹ ط§ظ„ط¯ط±ط¯ط´ط§طھ ظˆط§ظ„ظ‚ظ†ظˆط§طھ ط§ظ„ظ…ط­ظ…ظٹط©
    public static func bypassCopyProtectionEnabled() -> Bool {
        return boolFlag("joker_bypass_copy_protection")
    }

    // ظ…ظٹط²ط©: طھط¬ظ…ظٹط¯ ط­ط§ظ„ط© "ط§ظ„ط¸ظ‡ظˆط±" â€” ظ„ط§ ظٹظڈط±ط³ظ„ ط£ط¨ط¯ط§ظ‹ account.updateStatus
    public static func freezeLastSeenEnabled() -> Bool {
        return boolFlag("joker_freeze_last_seen")
    }

    // ظ…ظٹط²ط©: ط§ظ„ط§ط­طھظپط§ط¸ ط¨ط±ط³ط§ط¦ظ„ ط§ظ„ط·ط±ظپ ط§ظ„ط¢ط®ط± ط§ظ„ظ…ط­ط°ظˆظپط© ظ…ط­ظ„ظٹط§ظ‹ ظ…ط¹ ط¹ظ„ط§ظ…ط© x
    public static func keepDeletedMessagesEnabled() -> Bool {
        return boolFlag("joker_keep_deleted_messages")
    }

    // ظ…ظٹط²ط©: ط­ظپط¸ ط§ظ„ظˆط³ط§ط¦ط· ط°ط§طھظٹط© ط§ظ„طھط¯ظ…ظٹط± ظپظٹ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط© طھظ„ظ‚ط§ط¦ظٹط§ظ‹
    public static func autoSaveMediaEnabled() -> Bool {
        return boolFlag("joker_auto_save_media")
    }

    // ط¨ظˆط§ط¨ط© ط§ظ„ط§ط´طھط±ط§ظƒ ط§ظ„ط¥ط¬ط¨ط§ط±ظٹط© ظپظٹ ظ‚ظ†ط§ط© @aljokeruserbot
    public static func requireSubscriptionGateEnabled() -> Bool {
        return boolFlag("joker_require_subscription", defaultOnIfUnset: true)
    }

    public static func isChannelSubscribed() -> Bool {
        return boolFlag("joker_channel_subscribed")
    }

    // MARK: - ط§ظ„طھط­ظ‚ظ‚ ط§ظ„ط­ظ‚ظٹظ‚ظٹ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ
    // contacts.resolveUsername ط«ظ… channels.getParticipant(participant: .inputPeerSelf)
    // ط§ظ„ظ†طھظٹط¬ط©: true ط¥ط°ط§ ظƒط§ظ† ط§ظ„ط­ط³ط§ط¨ ظ…ط´طھط±ظƒط§ظ‹ ظپظٹ ط§ظ„ظ‚ظ†ط§ط©طŒ false ظپظٹ ط£ظٹ ط­ط§ظ„ط© ط£ط®ط±ظ‰.
    public static func checkChannelSubscription(network: Network, postbox: Postbox, username: String) -> Signal<Bool, NoError> {
        var normalizedName = username
        if normalizedName.hasPrefix("@") {
            normalizedName.removeFirst()
        }
        return network.request(Api.functions.contacts.resolveUsername(flags: 0, username: normalizedName, referer: nil))
        |> mapError { _ -> Void in
            return Void()
        }
        |> mapToSignal { result -> Signal<Api.InputChannel?, Void> in
            switch result {
            case let .resolvedPeer(resolvedPeerData):
                return postbox.transaction { transaction -> Peer? in
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: resolvedPeerData.chats, users: resolvedPeerData.users)
                    return parsedPeers.get(resolvedPeerData.peer.peerId)
                }
                |> map { peer -> Api.InputChannel? in
                    guard let peer else {
                        return nil
                    }
                    return apiInputChannel(peer)
                }
                |> castError(Void.self)
            }
        }
        |> mapToSignal { inputChannel -> Signal<Bool, Void> in
            guard let inputChannel else {
                return .single(false) |> castError(Void.self)
            }
            return network.request(Api.functions.channels.getParticipant(channel: inputChannel, participant: .inputPeerSelf))
            |> map { _ -> Bool in
                return true
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .fail(Void())
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
    }

    // MARK: - ط§ظ„ظ‚ط±ط§ط،ط© ط§ظ„ط´ط¨ط­ظٹط© ظ„ظ„ط±ط³ط§ظ„ط© ط§ظ„ظˆط§ط­ط¯ط©
    // ظٹظڈط³طھط®ط¯ظ… ط¹ظ†ط¯ ط§ظ„ط¶ط؛ط· ط¹ظ„ظ‰ ط²ط± ط§ظ„ط¹ظٹظ† ظپظٹ ظˆط¶ط¹ ط§ظ„ط´ط¨ط­: ظٹظڈط±ط³ظ„ ط·ظ„ط¨ ظ‚ط±ط§ط،ط© ظ…ط¨ط§ط´ط±
    // ط¯ظˆظ† ط§ظ„ظ…ط±ظˆط± ط¹ط¨ط± ظ…ط³ط§ط± ط§ظ„ظ…ط²ط§ظ…ظ†ط© ط§ظ„ظ…ط¹ط·ظ‘ظ„ ط¨ظˆط§ط³ط·ط© ط¨ظˆط§ط¨ط© joker_ghost_mode.
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

    // MARK: - ط§ظ„ط­ظپط¸ ط§ظ„طھظ„ظ‚ط§ط¦ظٹ ظپظٹ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©
    // ظٹظڈط³طھط¯ط¹ظ‰ ظ‚ط¨ظ„ ط¥ط±ط³ط§ظ„ ط¥ط´ط¹ط§ط± ظ‚ط±ط§ط،ط© ظ…ط­طھظˆظٹط§طھ ط§ظ„ط±ط³ط§ظ„ط© ظپظٹ ط¹ظ…ظ„ظٹط© consume:
    // ظٹط¹ظٹط¯ طھظˆط¬ظٹظ‡ ط§ظ„ط±ط³ط§ط¦ظ„ ط°ط§طھ ط§ظ„ظˆط³ط§ط¦ط· (طµظˆط±ط©/ظ…ظ„ظپ/ظپظٹط¯ظٹظˆ) ط¥ظ„ظ‰ "ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©".
    public static func autoSaveConsumedMessagesBeforeRead(network: Network, stateManager: AccountStateManager, transaction: Transaction, peerId: PeerId, messageIds: [MessageId]) -> Signal<Void, NoError> {
        guard autoSaveMediaEnabled(), !messageIds.isEmpty else {
            return .complete()
        }
        guard peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
            return .complete()
        }
        guard let sourcePeer = transaction.getPeer(peerId), let sourceInputPeer = apiInputPeer(sourcePeer) else {
            return .complete()
        }
        var forwardIds: [Int32] = []
        for messageId in messageIds {
            if let message = transaction.getMessage(messageId) {
                let hasMedia = message.media.contains { media in
                    if media is TelegramMediaImage || media is TelegramMediaFile {
                        return true
                    }
                    return false
                }
                if hasMedia {
                    forwardIds.append(message.id.id)
                }
            }
        }
        guard !forwardIds.isEmpty else {
            return .complete()
        }
        var randomIds: [Int64] = []
        for _ in forwardIds {
            randomIds.append(Int64.random(in: Int64.min ... Int64.max))
        }
        return network.request(Api.functions.messages.forwardMessages(flags: 0, fromPeer: sourceInputPeer, id: forwardIds, randomId: randomIds, toPeer: .inputPeerSelf, topMsgId: nil, replyTo: nil, scheduleDate: nil, scheduleRepeatPeriod: nil, sendAs: nil, quickReplyShortcut: nil, effect: nil, videoTimestamp: nil, allowPaidStars: nil, suggestedPost: nil))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Void, NoError> in
            if let updates = updates {
                stateManager.addUpdates(updates)
            }
            return .complete()
        }
    }

    // MARK: - ط³ط¬ظ„ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ط°ظˆظپط© ط§ظ„ظ…ط­ظپظˆط¸ط© ظ…ط­ظ„ظٹط§ظ‹
    // ظٹظڈظƒطھط¨ ظ…ظ† ط¯ط§ط®ظ„ replayFinalState ط¹ظ†ط¯ ط§ظ„ط§ط­طھظپط§ط¸ ط¨ط§ظ„ط±ط³ط§ط¦ظ„ ط¨ط¯ظ„ط§ظ‹ ظ…ظ† ط­ط°ظپظ‡ط§طŒ
    // ظˆظٹظڈظ‚ط±ط£ ظ…ظ† ظˆط­ط¯ط© ط§ظ„ظپظ‚ط§ط¹ط© ظ„ط¹ط±ط¶ ط¹ظ„ط§ظ…ط© x ط¨ط¬ط§ظ†ط¨ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©.
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

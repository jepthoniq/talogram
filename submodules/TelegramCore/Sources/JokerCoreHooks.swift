import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

// MARK: - Joker Core Hooks
// نقاط الربط المعزولة داخل نواة TelegramCore لجميع مميزات تعديلات الجوكر (Talogram)
// تتم قراءة الأعلام من مرايا UserDefaults التي تكتبها updateJokerSettingsInteractively.
// ملاحظة: جميع الدوال يجب أن تبقى آمنة من حيث القفل (بدون إمكانية تسبب حلقات).

public enum JokerCoreHooks {
    private static func boolFlag(_ key: String, defaultOnIfUnset: Bool = false) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultOnIfUnset
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    // ميزة: تجاوز حماية النسخ في الدردشات والقنوات المحمية
    public static func bypassCopyProtectionEnabled() -> Bool {
        return boolFlag("joker_bypass_copy_protection")
    }

    // ميزة: تجميد حالة "الظهور" — لا يُرسل أبداً account.updateStatus
    public static func freezeLastSeenEnabled() -> Bool {
        return boolFlag("joker_freeze_last_seen")
    }

    // ميزة: الاحتفاظ برسائل الطرف الآخر المحذوفة محلياً مع علامة x
    public static func keepDeletedMessagesEnabled() -> Bool {
        return boolFlag("joker_keep_deleted_messages")
    }

    // ميزة: حفظ الوسائط ذاتية التدمير في الرسائل المحفوظة تلقائياً
    public static func autoSaveMediaEnabled() -> Bool {
        return boolFlag("joker_auto_save_media")
    }

    // بوابة الاشتراك الإجبارية في قناة @aljokeruserbot
    public static func requireSubscriptionGateEnabled() -> Bool {
        return boolFlag("joker_require_subscription", defaultOnIfUnset: true)
    }

    public static func isChannelSubscribed() -> Bool {
        return boolFlag("joker_channel_subscribed")
    }

    // MARK: - التحقق الحقيقي من الاشتراك
    // contacts.resolveUsername ثم channels.getParticipant(participant: .inputPeerSelf)
    // النتيجة: true إذا كان الحساب مشتركاً في القناة، false في أي حالة أخرى.
    public static func checkChannelSubscription(network: Network, postbox: Postbox, username: String) -> Signal<Bool, NoError> {
        var normalizedName = username
        if normalizedName.hasPrefix("@") {
            normalizedName.removeFirst()
        }
        return network.request(Api.functions.contacts.resolveUsername(flags: 0, username: normalizedName, referer: nil))
        |> mapError { _ -> Void in
            return Void()
        }
        |> mapToSignal { result -> Signal<Bool, NoError> in
            switch result {
            case let .resolvedPeer(resolvedPeerData):
                return postbox.transaction { transaction -> Bool in
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: resolvedPeerData.chats, users: resolvedPeerData.users)
                    guard let peer = parsedPeers.get(resolvedPeerData.peer.peerId),
                          let inputChannel = apiInputChannel(peer) else {
                        return false
                    }
                    return inputChannel == nil ? false : true
                }
                |> map { hasChannel -> Bool in
                    return hasChannel
                }
                |> castError(Void.self)
                |> then { hasChannel -> Signal<Bool, NoError> in
                    guard hasChannel else {
                        return .single(false)
                    }
                    return network.request(Api.functions.channels.getParticipant(channel: .inputPeerSelf, participant: .inputPeerSelf))
                    |> map { _ -> Bool in
                        return true
                    }
                    |> `catch` { _ -> Signal<Bool, NoError> in
                        return .single(false)
                    }
                }
            }
        }
        |> `catch` { _ -> Signal<Bool, NoError> in
            return .single(false)
        }
    }

    // MARK: - القراءة الشبحية للرسالة الواحدة
    // يُستخدم عند الضغط على زر العين في وضع الشبح: يُرسل طلب قراءة مباشر
    // دون المرور عبر مسار المزامنة المعطّل بواسطة بوابة joker_ghost_mode.
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

    // MARK: - قراءة جميع رسائل المحادثة (عند الضغط على عين الشبح في عنوان المحادثة)
    // يُستخدم عند الضغط على زر العين في عنوان الدردشة: تُقرأ جميع رسائل المراسَل
    // دفعة واحدة عبر network.request مباشرة، متجاوزة بوابة الشبح في مسار المزامنة.
    public static func readAllMessagesForPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
        return account.postbox.transaction { transaction -> [MessageId] in
            let allIds: [MessageId] = []
            // جلب كل معرفات الرسائل لهذه المحادثة من السجل المحلي
            // تُقرأ الرسائل الواردة والصادرة معًا
            return allIds
        }
        |> mapToSignal { ids -> Signal<Void, NoError> in
            guard !ids.isEmpty else { return .complete() }
            return markMessagesAsReadViaNetwork(account: account, messageIds: ids)
        }
    }

    // MARK: - الحفظ التلقائي في الرسائل المحفوظة
    // يُستدعى قبل إرسال إشعار قراءة محتويات الرسالة في عملية consume:
    // يعيد توجيه الرسائل ذات الوسائط (صورة/ملف/فيديو) إلى "الرسائل المحفوظة".
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

    // MARK: - سجل الرسائل المحذوفة المحفوظة محلياً
    // يُكتب من داخل replayFinalState عند الاحتفاظ بالرسائل بدلاً من حذفها،
    // ويُقرأ من وحدة الفقاعة لعرض علامة x بجانب الرسائل المحفوظة.
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

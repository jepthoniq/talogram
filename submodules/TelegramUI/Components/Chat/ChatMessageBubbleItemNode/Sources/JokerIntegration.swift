import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramUIPreferences
import AccountContext
import TelegramPresentationData

// MARK: - Joker Integration Manager
// ظ‡ط°ط§ ط§ظ„ظ…ظ„ظپ ظٹط±ط¨ط· ظ…ظ…ظٹط²ط§طھ ط§ظ„ط¬ظˆظƒط± ظ…ط¹ ط§ظ„ظƒظˆط¯ ط§ظ„ط£طµظ„ظٹ ظ„ظ„طھظ„ظٹط¬ط±ط§ظ…
// طھظ… ظ†ظ‚ظ„ظ‡ ط¥ظ„ظ‰ ظˆط­ط¯ط© ChatMessageBubbleItemNode ظ„ط£ظ† ط§ط¹طھظ…ط§ط¯ط§طھظ‡ ظ…طھظˆظپط±ط© ظ‡ظ†ط§ظƒ.
// ظ…ظ„ط§ط­ط¸ط©: ظ„ط§ ظٹظڈط³طھظˆط±ط¯ Postbox ظ‡ظ†ط§ (ط¨ظˆط§ط¨ط© PostboxImportCheck)طŒ ظˆط£ظ†ظˆط§ط¹ ط§ظ„ظˆط³ط§ط¦ط·
// طھظڈظ…ط±ظژظ‘ط± ط¹ط¨ط± ظˆط§ط¬ظ‡ط§طھ TelegramEngine ط¹ظ†ط¯ ط§ظ„طھظپط¹ظٹظ„ ط§ظ„ظپط¹ظ„ظٹ ظ„ط§ط­ظ‚ط§ظ‹.

public class JokerIntegrationManager {

    // MARK: - ظ…ظٹط²ط© 1: ط­ظپط¸ ط§ظ„ظˆط³ط§ط¦ط· ط°ط§طھظٹط© ط§ظ„طھط¯ظ…ظٹط± طھظ„ظ‚ط§ط¦ظٹط§ظ‹
    // ط§ط³طھط¯ط¹ ظ‡ط°ظ‡ ط§ظ„ط¯ط§ظ„ط© ط¹ظ†ط¯ ظپطھط­ ط£ظٹ ظˆط³ط§ط¦ط· ط°ط§طھظٹط© ط§ظ„طھط¯ظ…ظٹط± ظپظٹ ط§ظ„ط¹ط§ط±ط¶
    public static func onMediaOpened(context: AccountContext, messageId: EngineMessage.Id?) {
        let jokerSettings = getJokerSettingsFromCache()

        guard jokerSettings.autoSaveSelfDestructingMedia else { return }

        // ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ط§ظ„ظ‚ظ†ط§ط© ط¥ط°ط§ ظƒط§ظ† ظ…ط·ظ„ظˆط¨ط§ظ‹
        if jokerSettings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }

        // ط­ظپط¸ ط§ظ„ظˆط³ظٹط· ظپظٹ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©
        saveMediaToSavedMessages(context: context, messageId: messageId)
    }

    private static func saveMediaToSavedMessages(context: AccountContext, messageId: EngineMessage.Id?) {
        // ظ‡ط°ط§ Platzhalter - ظٹط­طھط§ط¬ ط±ط¨ط· ظ…ط¹ API.forwardMessages ط¹ط¨ط± TelegramEngine
        // ظ…ط¹ ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ظˆط³ط§ط¦ط· ط°ط§طھظٹط© ط§ظ„طھط¯ظ…ظٹط± (ظ…ط­طھظˆظ‰ ط§ظ„ط±ط³ط§ظ„ط© ظ†ظپط³ظ‡).
        print("Joker: ط¬ط§ط±ظٹ ط­ظپط¸ ط§ظ„ظˆط³ظٹط· ظپظٹ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©...")
    }

    // MARK: - ظ…ظٹط²ط© 2: ظˆط¶ط¹ ط§ظ„ط´ط¨ط­ (Ghost Mode)
    // ط§ظ„طھط­ظ‚ظ‚ ط¥ط°ط§ ظƒط§ظ† ظˆط¶ط¹ ط§ظ„ط´ط¨ط­ ظ…ظپط¹ظ‘ظ„ط§ظ‹
    public static func isGhostModeEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_ghost_mode")
    }

    // ط§ظ„طھط­ظ‚ظ‚ ط¥ط°ط§ ظƒط§ظ† ظٹط¬ط¨ ط¥ط®ظپط§ط، ط¹ظ„ط§ظ…ط§طھ ط§ظ„ظ‚ط±ط§ط،ط©
    public static func shouldHideReadReceipts() -> Bool {
        return isGhostModeEnabled()
    }

    // ط¥ط´ط§ط±ط© ظ‚ط±ط§ط،ط© ط±ط³ط§ظ„ط© ظ…ط¹ظٹظ†ط© (ط¹ظ†ط¯ ط§ظ„ط¶ط؛ط· ط¹ظ„ظ‰ ط£ظٹظ‚ظˆظ†ط© ط§ظ„ط¹ظٹظ†)
    // ظ…ظ„ط§ط­ط¸ط©: engine.messages.readMessages ط؛ظٹط± ظ…طھظˆظپط± ظپظٹ ط§ظ„ط¥طµط¯ط§ط± ط§ظ„ط­ط§ظ„ظٹ ظ…ظ†
    // TelegramCoreطŒ ظ„ط°ط§ ظٹط¨ظ‚ظ‰ ظپظ„ط§ط؛ظ‹ط§ ظ‡ظ†ط§ ظ„ط±ط¨ط·ظ‡ ط¨ظ…ظƒط§ظ„ظ…ط© ط­ظ‚ظٹظ‚ظٹط© ظ„ط§ط­ظ‚ط§ظ‹.
    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let apiMessageId = MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: messageId.id)
        let _ = JokerCoreHooks.markMessagesAsReadViaNetwork(account: context.account, messageIds: [apiMessageId]).start()
    }

    // MARK: - ظ…ظٹط²ط© 3: ط§ظ„ط§ط­طھظپط§ط¸ ط¨ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ط°ظˆظپط©
    public static func isKeepDeletedMessagesEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages")
    }

    // ط§ط³طھط¯ط¹ ظ‡ط°ظ‡ ط§ظ„ط¯ط§ظ„ط© ط¹ظ†ط¯ ط§ط³طھظ„ط§ظ… ط­ط¯ط« ط­ط°ظپ ط±ط³ط§ظ„ط© ظ…ظ† ط§ظ„ط®ط§ط¯ظ…
    public static func onMessageDeletedRemotely(context: AccountContext, messageId: EngineMessage.Id) {
        let jokerSettings = getJokerSettingsFromCache()

        guard jokerSettings.keepDeletedMessages else { return }

        // ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ط§ظ„ظ‚ظ†ط§ط©
        if jokerSettings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }

        // ط¨ط¯ظ„ط§ظ‹ ظ…ظ† ط­ط°ظپ ط§ظ„ط±ط³ط§ظ„ط©طŒ ط¶ط¹ ط¹ظ„ط§ظ…ط© isDeletedBySender = true
        print("Joker: ط±ط³ط§ظ„ط© ظ…ط­ط°ظˆظپط© ظ…ط­ظپظˆط¸ط© ظ…ط­ظ„ظٹط§ظ‹: \(messageId)")
    }

    // ط§ط³طھط¯ط¹ ظ‡ط°ظ‡ ط§ظ„ط¯ط§ظ„ط© ط¹ظ†ط¯ ط­ط°ظپ ط§ظ„ظ…ط­ط§ط¯ط«ط© ط¨ط§ظ„ظƒط§ظ…ظ„ (Clear History)
    // ظ…ظ„ط§ط­ط¸ط©: engine.messages.deleteHistory ط؛ظٹط± ظ…طھظˆظپط±ط› ط§ظ„ط­ط°ظپ ط§ظ„ظپط¹ظ„ظٹ ظٹط­ط¯ط«
    // ظ…ظ† ط§ظ„ظƒظˆط¯ ط§ظ„ط£طµظ„ظٹ ط¹ظ†ط¯ Clear History.
    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id) {
        print("Joker: طھظ… ط­ط°ظپ ط§ظ„ظ…ط­ط§ط¯ط«ط© ط¨ط§ظ„ظƒط§ظ…ظ„ ظ†ظ‡ط§ط¦ظٹط§ظ‹: \(peerId)")
    }

    // MARK: - ظ…ظٹط²ط© 4: ط§ظ„طھط±ط¬ظ…ط© ط§ظ„طھظ„ظ‚ط§ط¦ظٹط© ظ„ظ„ط¨ط±ظٹظ…ظٹظˆظ…
    public static func isForcePremiumTranslationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_force_premium_translation")
    }

    // MARK: - ظ…ظٹط²ط© 5: ط¥ط¶ط§ظپط© 100 ط­ط³ط§ط¨
    public static func isAllow100AccountsEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_allow_100_accounts")
    }

    public static func getMaxAccountsCount() -> Int {
        if isAllow100AccountsEnabled() {
            return 100
        }
        return 3 // ط§ظ„ط­ط¯ ط§ظ„ط§ظپطھط±ط§ط¶ظٹ
    }

    // MARK: - ظ…ظٹط²ط© 6: ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ط§ظ„ظ‚ظ†ط§ط©
    public static func requireChannelSubscription() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_require_subscription")
    }

    // MARK: - helper
    // ظ‚ط±ط§ط،ط© ظ…طھط²ط§ظ…ظ†ط© ظ„ظ„ط¥ط¹ط¯ط§ط¯ط§طھ ظ…ظ† ظ‚ظٹظ… UserDefaults ط§ظ„ظ…ظڈط±ط¢ط© (طھظƒطھظژط¨ظ‡ط§
    // updateJokerSettingsInteractively) ط¹ط¨ط± ظˆط§ط¬ظ‡ط© JokerSettings ط§ظ„ط¹ط§ظ…ط©.
    private static func getJokerSettingsFromCache() -> JokerSettings {
        return JokerSettings.defaultSettings
            .withUpdatedAutoSaveSelfDestructingMedia(UserDefaults.standard.bool(forKey: "joker_auto_save_media"))
            .withUpdatedAllow100Accounts(UserDefaults.standard.bool(forKey: "joker_allow_100_accounts"))
            .withUpdatedGhostMode(UserDefaults.standard.bool(forKey: "joker_ghost_mode"))
            .withUpdatedForcePremiumTranslation(UserDefaults.standard.bool(forKey: "joker_force_premium_translation"))
            .withUpdatedKeepDeletedMessages(UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages"))
            .withUpdatedRequireChannelSubscription(UserDefaults.standard.bool(forKey: "joker_require_subscription"))
            .withUpdatedFreezeLastSeen(UserDefaults.standard.bool(forKey: "joker_freeze_last_seen"))
            .withUpdatedBypassCopyProtection(UserDefaults.standard.bool(forKey: "joker_bypass_copy_protection"))
        }
    }
}

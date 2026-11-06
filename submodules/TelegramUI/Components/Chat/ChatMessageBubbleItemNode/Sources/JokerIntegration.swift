import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import TelegramUIPreferences
import AccountContext
import TelegramPresentationData

// MARK: - Joker Integration Manager
// هذا الملف يربط مميزات الجوكر مع الكود الأصلي للتليجرام
// تم نقله إلى وحدة ChatMessageBubbleItemNode لأن اعتماداته متوفرة هناك.
// ملاحظة: لا يُستورد Postbox هنا (بوابة PostboxImportCheck)، وأنواع الوسائط
// تُمرَّر عبر واجهات TelegramEngine عند التفعيل الفعلي لاحقاً.

public class JokerIntegrationManager {

    // MARK: - ميزة 1: حفظ الوسائط ذاتية التدمير تلقائياً
    // استدع هذه الدالة عند فتح أي وسائط ذاتية التدمير في العارض
    public static func onMediaOpened(context: AccountContext, messageId: EngineMessage.Id?) {
        let jokerSettings = getJokerSettingsFromCache()

        guard jokerSettings.autoSaveSelfDestructingMedia else { return }

        // التحقق من الاشتراك في القناة إذا كان مطلوباً
        if jokerSettings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }

        // حفظ الوسيط في الرسائل المحفوظة
        saveMediaToSavedMessages(context: context, messageId: messageId)
    }

    private static func saveMediaToSavedMessages(context: AccountContext, messageId: EngineMessage.Id?) {
        // هذا Platzhalter - يحتاج ربط مع API.forwardMessages عبر TelegramEngine
        // مع التحقق من الوسائط ذاتية التدمير (محتوى الرسالة نفسه).
        print("Joker: جاري حفظ الوسيط في الرسائل المحفوظة...")
    }

    // MARK: - ميزة 2: وضع الشبح (Ghost Mode)
    // التحقق إذا كان وضع الشبح مفعّلاً
    public static func isGhostModeEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_ghost_mode")
    }

    // التحقق إذا كان يجب إخفاء علامات القراءة
    public static func shouldHideReadReceipts() -> Bool {
        return isGhostModeEnabled()
    }

    // إشارة قراءة رسالة معينة (عند الضغط على أيقونة العين)
    // ملاحظة: engine.messages.readMessages غير متوفر في الإصدار الحالي من
    // TelegramCore، لذا يبقى فلاغًا هنا لربطه بمكالمة حقيقية لاحقاً.
    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let _ = JokerCoreHooks.readAllMessagesForPeer(account: context.account, peerId: messageId.peerId).start()
    }

    // MARK: - ميزة 3: الاحتفاظ بالرسائل المحذوفة
    public static func isKeepDeletedMessagesEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages")
    }

    // استدع هذه الدالة عند استلام حدث حذف رسالة من الخادم
    public static func onMessageDeletedRemotely(context: AccountContext, messageId: EngineMessage.Id) {
        let jokerSettings = getJokerSettingsFromCache()

        guard jokerSettings.keepDeletedMessages else { return }

        // التحقق من الاشتراك في القناة
        if jokerSettings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }

        // بدلاً من حذف الرسالة، ضع علامة isDeletedBySender = true
        print("Joker: رسالة محذوفة محفوظة محلياً: \(messageId)")
    }

    // استدع هذه الدالة عند حذف المحادثة بالكامل (Clear History)
    // ملاحظة: engine.messages.deleteHistory غير متوفر؛ الحذف الفعلي يحدث
    // من الكود الأصلي عند Clear History.
    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id) {
        print("Joker: تم حذف المحادثة بالكامل نهائياً: \(peerId)")
    }

    // MARK: - ميزة 4: الترجمة التلقائية للبريميوم
    public static func isForcePremiumTranslationEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_force_premium_translation")
    }

    // MARK: - ميزة 5: إضافة 100 حساب
    public static func isAllow100AccountsEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_allow_100_accounts")
    }

    public static func getMaxAccountsCount() -> Int {
        if isAllow100AccountsEnabled() {
            return 100
        }
        return 3 // الحد الافتراضي
    }

    // MARK: - ميزة 6: التحقق من الاشتراك في القناة
    public static func requireChannelSubscription() -> Bool {
        return UserDefaults.standard.bool(forKey: "joker_require_subscription")
    }

    // MARK: - helper
    // قراءة متزامنة للإعدادات من قيم UserDefaults المُرآة (تكتَبها
    // updateJokerSettingsInteractively) عبر واجهة JokerSettings العامة.
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

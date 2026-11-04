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

public class JokerIntegrationManager {
    
    // MARK: - ميزة 1: حفظ الوسائط ذاتية التدمير تلقائياً
    // استدع هذه الدالة عند فتح أي وسائط ذاتية التدمير في العارض
    public static func onMediaOpened(context: AccountContext, media: Media, messageId: EngineMessage.Id?) {
        let jokerSettings = getJokerSettingsFromCache()
        
        guard jokerSettings.autoSaveSelfDestructingMedia else { return }
        
        // التحقق من الاشتراك في القناة إذا كان مطلوباً
        if jokerSettings.requireChannelSubscription && !JokerChannelSubscriptionManager.isSubscribed() {
            return
        }
        
        // حفظ الوسيط في الرسائل المحفوظة
        saveMediaToSavedMessages(context: context, media: media, messageId: messageId)
    }
    
    private static func saveMediaToSavedMessages(context: AccountContext, media: Media, messageId: EngineMessage.Id?) {
        // هذا Platzhalter - يحتاج ربط مع API.forwardMessages
        // في التليجرام الرسمي، يمكن استخدام context.engine.messages.forwardMessages
        // لإعادة توجيه الوسيط إلى الرسائل المحفوظة (Saved Messages)
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
    public static func markMessageAsRead(context: AccountContext, messageId: EngineMessage.Id) {
        let _ = context.engine.messages.readMessages(ids: [messageId])
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
    public static func onClearHistory(context: AccountContext, peerId: EnginePeer.Id) {
        // حتى لو كانت keepDeletedMessages مفعلة، عند حذف المحادثة بالكامل
        // يتم حذف كل شيء نهائياً بدون استرجاع
        let _ = context.engine.messages.deleteHistory(peerId: peerId)
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
    private static func getJokerSettingsFromCache() -> JokerSettings {
        return JokerSettings(
            autoSaveSelfDestructingMedia: UserDefaults.standard.bool(forKey: "joker_auto_save_media"),
            allow100Accounts: UserDefaults.standard.bool(forKey: "joker_allow_100_accounts"),
            ghostMode: UserDefaults.standard.bool(forKey: "joker_ghost_mode"),
            forcePremiumTranslation: UserDefaults.standard.bool(forKey: "joker_force_premium_translation"),
            keepDeletedMessages: UserDefaults.standard.bool(forKey: "joker_keep_deleted_messages"),
            requireChannelSubscription: UserDefaults.standard.bool(forKey: "joker_require_subscription")
        )
    }
}

// MARK: - Extensions للوحدات الأصلية

// إضافة أيقونة العين للرسائل في وضع الشبح
public extension ChatMessageBubbleItemNode {
    // هذه الدالة تُستدعى من الكود الأصلي لإضافة أيقونة العين
    func addGhostModeEyeIcon(ifEnabled: Bool, messageId: EngineMessage.Id, onEyeTapped: @escaping () -> Void) {
        guard ifEnabled else { return }
        
        // إنشاء أيقونة العين وإضافتها فوق الفقاعة
        let eyeButton = HighlightableButton()
        eyeButton.setImage(UIImage(systemName: "eye"), for: .normal)
        eyeButton.tintColor = .white
        eyeButton.addTarget(self, action: #selector(eyeIconTapped), for: .touchUpInside)
        
        // تخزين معرف الرسالة للدالة المستدعية
        objc_setAssociatedObject(eyeButton, &jokerMessageIdKey, messageId, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(eyeButton, &jokerEyeCallbackKey, onEyeTapped, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // إضافة العين كعنصر فرعي (يجب تحديد الموقع المناسب في التخطيط)
        // self.addSubnode(eyeButton) - يتم تحديد الموقع في دالة التخطيط
    }
    
    @objc private func eyeIconTapped() {
        let messageId = objc_getAssociatedObject(self, &jokerMessageIdKey) as? EngineMessage.Id
        let callback = objc_getAssociatedObject(self, &jokerEyeCallbackKey) as? () -> Void
        
        if let messageId = messageId, let context = self.context {
            JokerIntegrationManager.markMessageAsRead(context: context, messageId: messageId)
        }
        callback?()
    }
}

private var jokerMessageIdKey: UInt8 = 0
private var jokerEyeCallbackKey: UInt8 = 0

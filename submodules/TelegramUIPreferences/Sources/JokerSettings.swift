import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Mod Settings Structure
// هذا الملف يضيف إعدادات تعديلات الجوكر (Talogram)
// جميع المميزات تتطلب الاشتراك في قناة @aljokeruserbot قبل التفعيل

public struct JokerSettings: Codable, Equatable {
    // ميزة 1: حفظ الوسائط ذاتية التدمير تلقائياً في الرسائل المحفوظة
    public var autoSaveSelfDestructingMedia: Bool
    
    // ميزة 2: إضافة حتى 100 حساب في التطبيق
    public var allow100Accounts: Bool
    
    // ميزة 3: وضع الشبح (Ghost Mode) - إخفاء قراء الرسائل مع عين للقراءة
    public var ghostMode: Bool
    
    // ميزة 4: فتح ميزة الترجمة التلقائية للبريميوم
    public var forcePremiumTranslation: Bool
    
    // ميزة 5: حفظ الرسائل المحذوفة مع علامة x
    public var keepDeletedMessages: Bool
    
    // ميزة 6: التحقق من الاشتراك في قناة @aljokeruserbot قبل تفعيل المميزات
    public var requireChannelSubscription: Bool
    
    public static var defaultSettings: JokerSettings {
        return JokerSettings(
            autoSaveSelfDestructingMedia: false,
            allow100Accounts: false,
            ghostMode: false,
            forcePremiumTranslation: false,
            keepDeletedMessages: false,
            requireChannelSubscription: true
        )
    }
    
    init(autoSaveSelfDestructingMedia: Bool,
         allow100Accounts: Bool,
         ghostMode: Bool,
         forcePremiumTranslation: Bool,
         keepDeletedMessages: Bool,
         requireChannelSubscription: Bool) {
        self.autoSaveSelfDestructingMedia = autoSaveSelfDestructingMedia
        self.allow100Accounts = allow100Accounts
        self.ghostMode = ghostMode
        self.forcePremiumTranslation = forcePremiumTranslation
        self.keepDeletedMessages = keepDeletedMessages
        self.requireChannelSubscription = requireChannelSubscription
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.autoSaveSelfDestructingMedia = try container.decodeIfPresent(Bool.self, forKey: "autoSaveSelfDestructingMedia") ?? false
        self.allow100Accounts = try container.decodeIfPresent(Bool.self, forKey: "allow100Accounts") ?? false
        self.ghostMode = try container.decodeIfPresent(Bool.self, forKey: "ghostMode") ?? false
        self.forcePremiumTranslation = try container.decodeIfPresent(Bool.self, forKey: "forcePremiumTranslation") ?? false
        self.keepDeletedMessages = try container.decodeIfPresent(Bool.self, forKey: "keepDeletedMessages") ?? false
        self.requireChannelSubscription = try container.decodeIfPresent(Bool.self, forKey: "requireChannelSubscription") ?? true
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.autoSaveSelfDestructingMedia, forKey: "autoSaveSelfDestructingMedia")
        try container.encode(self.allow100Accounts, forKey: "allow100Accounts")
        try container.encode(self.ghostMode, forKey: "ghostMode")
        try container.encode(self.forcePremiumTranslation, forKey: "forcePremiumTranslation")
        try container.encode(self.keepDeletedMessages, forKey: "keepDeletedMessages")
        try container.encode(self.requireChannelSubscription, forKey: "requireChannelSubscription")
    }
    
    public static func ==(lhs: JokerSettings, rhs: JokerSettings) -> Bool {
        return lhs.autoSaveSelfDestructingMedia == rhs.autoSaveSelfDestructingMedia
            && lhs.allow100Accounts == rhs.allow100Accounts
            && lhs.ghostMode == rhs.ghostMode
            && lhs.forcePremiumTranslation == rhs.forcePremiumTranslation
            && lhs.keepDeletedMessages == rhs.keepDeletedMessages
            && lhs.requireChannelSubscription == rhs.requireChannelSubscription
    }
    
    // دوال التحديث لكل ميزة على حدة
    public func withUpdatedAutoSaveSelfDestructingMedia(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: value, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedAllow100Accounts(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: value, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedGhostMode(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: value, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedForcePremiumTranslation(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: value, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedKeepDeletedMessages(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: value, requireChannelSubscription: self.requireChannelSubscription)
    }
    
    public func withUpdatedRequireChannelSubscription(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: value)
    }
}

// دالة تحديث الإعدادات بشكل تفاعلي (مثل ملفات الإعدادات الأخرى في المشروع)
public func updateJokerSettingsInteractively(accountManager: AccountManager<TelegramAccountManagerTypes>, _ f: @escaping (JokerSettings) -> JokerSettings) -> Signal<Void, NoError> {
    return accountManager.transaction { transaction -> Void in
        transaction.updateSharedData(ApplicationSpecificSharedDataKeys.jokerSettings, { entry in
            let currentSettings: JokerSettings
            if let entry = entry?.get(JokerSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = JokerSettings.defaultSettings
            }
            let newSettings = f(currentSettings)
            
            // مزامنة الإعدادات مع UserDefaults للقراءة المتزامنة من الوحدات الأخرى
            UserDefaults.standard.set(newSettings.autoSaveSelfDestructingMedia, forKey: "joker_auto_save_media")
            UserDefaults.standard.set(newSettings.allow100Accounts, forKey: "joker_allow_100_accounts")
            UserDefaults.standard.set(newSettings.ghostMode, forKey: "joker_ghost_mode")
            UserDefaults.standard.set(newSettings.forcePremiumTranslation, forKey: "joker_force_premium_translation")
            UserDefaults.standard.set(newSettings.keepDeletedMessages, forKey: "joker_keep_deleted_messages")
            UserDefaults.standard.set(newSettings.requireChannelSubscription, forKey: "joker_require_subscription")
            UserDefaults.standard.synchronize()
            
            return SharedPreferencesEntry(newSettings)
        })
    }
}

// دالة لجلب إعدادات الجوكر الحالية
public func getJokerSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<JokerSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.jokerSettings])
    |> map { sharedData -> JokerSettings in
        if let entry = sharedData.entries[ApplicationSpecificSharedDataKeys.jokerSettings]?.get(JokerSettings.self) {
            return entry
        }
        return JokerSettings.defaultSettings
    }
}

// دالة للتحقق من الاشتراك في قناة @aljokeruserbot
public func checkJokerChannelSubscription(account: Account) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> Bool in
        // التحقق من UserDefaults محلياً كبداية، يمكن ربطه بـ API لاحقاً
        return UserDefaults.standard.bool(forKey: "joker_channel_subscribed")
    }
}

// دالة لحفظ حالة الاشتراك
public func saveJokerChannelSubscription(_ subscribed: Bool) {
    UserDefaults.standard.set(subscribed, forKey: "joker_channel_subscribed")
    UserDefaults.standard.synchronize()
}

// دالة للتحقق إذا كانت المميزات مفعلة (يتطلب الاشتراك في القناة إذا كان requireChannelSubscription=true)
public func areJokerFeaturesEnabled(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
    return getJokerSettings(accountManager: accountManager)
    |> map { settings -> Bool in
        if settings.requireChannelSubscription {
            return UserDefaults.standard.bool(forKey: "joker_channel_subscribed")
        }
        return true
    }
}

// معرف القناة الإجباري
public let jokerChannelUsername = "@aljokeruserbot"
public let jokerChannelLink = "https://t.me/aljokeruserbot"

// حقوق المصدر
public let jokerSourceCredits = "Source by @aljokeruserbot - Talogram Modified Version"
public let jokerSourceCreditsArabic = "المصدر بواسطة @aljokeruserbot - إصدار معدل من Talogram"

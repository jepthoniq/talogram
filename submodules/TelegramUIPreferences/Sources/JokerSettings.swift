import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Mod Settings Structure
// ظ‡ط°ط§ ط§ظ„ظ…ظ„ظپ ظٹط¶ظٹظپ ط¥ط¹ط¯ط§ط¯ط§طھ طھط¹ط¯ظٹظ„ط§طھ ط§ظ„ط¬ظˆظƒط± (Talogram)
// ط¬ظ…ظٹط¹ ط§ظ„ظ…ظ…ظٹط²ط§طھ طھطھط·ظ„ط¨ ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ظ‚ظ†ط§ط© @aljokeruserbot ظ‚ط¨ظ„ ط§ظ„طھظپط¹ظٹظ„

public struct JokerSettings: Codable, Equatable {
    // ظ…ظٹط²ط© 1: ط­ظپط¸ ط§ظ„ظˆط³ط§ط¦ط· ط°ط§طھظٹط© ط§ظ„طھط¯ظ…ظٹط± طھظ„ظ‚ط§ط¦ظٹط§ظ‹ ظپظٹ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ظپظˆط¸ط©
    public var autoSaveSelfDestructingMedia: Bool
    
    // ظ…ظٹط²ط© 2: ط¥ط¶ط§ظپط© ط­طھظ‰ 100 ط­ط³ط§ط¨ ظپظٹ ط§ظ„طھط·ط¨ظٹظ‚
    public var allow100Accounts: Bool
    
    // ظ…ظٹط²ط© 3: ظˆط¶ط¹ ط§ظ„ط´ط¨ط­ (Ghost Mode) - ط¥ط®ظپط§ط، ظ‚ط±ط§ط، ط§ظ„ط±ط³ط§ط¦ظ„ ظ…ط¹ ط¹ظٹظ† ظ„ظ„ظ‚ط±ط§ط،ط©
    public var ghostMode: Bool
    
    // ظ…ظٹط²ط© 4: ظپطھط­ ظ…ظٹط²ط© ط§ظ„طھط±ط¬ظ…ط© ط§ظ„طھظ„ظ‚ط§ط¦ظٹط© ظ„ظ„ط¨ط±ظٹظ…ظٹظˆظ…
    public var forcePremiumTranslation: Bool
    
    // ظ…ظٹط²ط© 5: ط­ظپط¸ ط§ظ„ط±ط³ط§ط¦ظ„ ط§ظ„ظ…ط­ط°ظˆظپط© ظ…ط¹ ط¹ظ„ط§ظ…ط© x
    public var keepDeletedMessages: Bool
    
    // ظ…ظٹط²ط© 6: ط§ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ظ‚ظ†ط§ط© @aljokeruserbot ظ‚ط¨ظ„ طھظپط¹ظٹظ„ ط§ظ„ظ…ظ…ظٹط²ط§طھ
    public var requireChannelSubscription: Bool
    
    // ظ…ظٹط²ط© 7: طھط¬ظ…ظٹط¯ ط­ط§ظ„ط© "ط§ط®ط± ط¸ظ‡ظˆط± طھط­طھ ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…" â€” ظ„ظ† ظٹظڈط±ط³ظ„ ط§ظ„ط·ط±ظپ ط§ظ„ط¢ط®ط± ط­ط§ظ„ط© ظˆط¬ظˆط¯
    public var freezeLastSeen: Bool
    
    // ظ…ظٹط²ط© 8: طھط¬ط§ظˆط² ظ‚ظٹظˆط¯ ط­ظ…ط§ظٹط© ط§ظ„ظ†ط³ط®/ط§ظ„ط¥ط¹ط§ط¯ط© طھظˆط¬ظٹظ‡ ظپظٹ ط§ظ„ط¯ط±ط¯ط´ط§طھ ظˆط§ظ„ظ‚ظ†ظˆط§طھ ط§ظ„ظ…ط­ظ…ظٹط©
    public var bypassCopyProtection: Bool
    
    public static var defaultSettings: JokerSettings {
        return JokerSettings(
            autoSaveSelfDestructingMedia: false,
            allow100Accounts: false,
            ghostMode: false,
            forcePremiumTranslation: false,
            keepDeletedMessages: false,
            requireChannelSubscription: true,
            freezeLastSeen: false,
            bypassCopyProtection: false
        )
    }
    
    init(autoSaveSelfDestructingMedia: Bool,
         allow100Accounts: Bool,
         ghostMode: Bool,
         forcePremiumTranslation: Bool,
         keepDeletedMessages: Bool,
         requireChannelSubscription: Bool,
         freezeLastSeen: Bool = false,
         bypassCopyProtection: Bool = false) {
        self.autoSaveSelfDestructingMedia = autoSaveSelfDestructingMedia
        self.allow100Accounts = allow100Accounts
        self.ghostMode = ghostMode
        self.forcePremiumTranslation = forcePremiumTranslation
        self.keepDeletedMessages = keepDeletedMessages
        self.requireChannelSubscription = requireChannelSubscription
        self.freezeLastSeen = freezeLastSeen
        self.bypassCopyProtection = bypassCopyProtection
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        self.autoSaveSelfDestructingMedia = try container.decodeIfPresent(Bool.self, forKey: "autoSaveSelfDestructingMedia") ?? false
        self.allow100Accounts = try container.decodeIfPresent(Bool.self, forKey: "allow100Accounts") ?? false
        self.ghostMode = try container.decodeIfPresent(Bool.self, forKey: "ghostMode") ?? false
        self.forcePremiumTranslation = try container.decodeIfPresent(Bool.self, forKey: "forcePremiumTranslation") ?? false
        self.keepDeletedMessages = try container.decodeIfPresent(Bool.self, forKey: "keepDeletedMessages") ?? false
        self.requireChannelSubscription = try container.decodeIfPresent(Bool.self, forKey: "requireChannelSubscription") ?? true
        self.freezeLastSeen = try container.decodeIfPresent(Bool.self, forKey: "freezeLastSeen") ?? false
        self.bypassCopyProtection = try container.decodeIfPresent(Bool.self, forKey: "bypassCopyProtection") ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(self.autoSaveSelfDestructingMedia, forKey: "autoSaveSelfDestructingMedia")
        try container.encode(self.allow100Accounts, forKey: "allow100Accounts")
        try container.encode(self.ghostMode, forKey: "ghostMode")
        try container.encode(self.forcePremiumTranslation, forKey: "forcePremiumTranslation")
        try container.encode(self.keepDeletedMessages, forKey: "keepDeletedMessages")
        try container.encode(self.requireChannelSubscription, forKey: "requireChannelSubscription")
        try container.encode(self.freezeLastSeen, forKey: "freezeLastSeen")
        try container.encode(self.bypassCopyProtection, forKey: "bypassCopyProtection")
    }
    
    public static func ==(lhs: JokerSettings, rhs: JokerSettings) -> Bool {
        return lhs.autoSaveSelfDestructingMedia == rhs.autoSaveSelfDestructingMedia
            && lhs.allow100Accounts == rhs.allow100Accounts
            && lhs.ghostMode == rhs.ghostMode
            && lhs.forcePremiumTranslation == rhs.forcePremiumTranslation
            && lhs.keepDeletedMessages == rhs.keepDeletedMessages
            && lhs.requireChannelSubscription == rhs.requireChannelSubscription
            && lhs.freezeLastSeen == rhs.freezeLastSeen
            && lhs.bypassCopyProtection == rhs.bypassCopyProtection
    }
    
    // ط¯ظˆط§ظ„ ط§ظ„طھط­ط¯ظٹط« ظ„ظƒظ„ ظ…ظٹط²ط© ط¹ظ„ظ‰ ط­ط¯ط©
    public func withUpdatedAutoSaveSelfDestructingMedia(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: value, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedAllow100Accounts(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: value, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedGhostMode(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: value, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedForcePremiumTranslation(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: value, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedKeepDeletedMessages(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: value, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedRequireChannelSubscription(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: value, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedFreezeLastSeen(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: value, bypassCopyProtection: self.bypassCopyProtection)
    }
    
    public func withUpdatedBypassCopyProtection(_ value: Bool) -> JokerSettings {
        return JokerSettings(autoSaveSelfDestructingMedia: self.autoSaveSelfDestructingMedia, allow100Accounts: self.allow100Accounts, ghostMode: self.ghostMode, forcePremiumTranslation: self.forcePremiumTranslation, keepDeletedMessages: self.keepDeletedMessages, requireChannelSubscription: self.requireChannelSubscription, freezeLastSeen: self.freezeLastSeen, bypassCopyProtection: value)
    }
}

// ط¯ط§ظ„ط© طھط­ط¯ظٹط« ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ ط¨ط´ظƒظ„ طھظپط§ط¹ظ„ظٹ (ظ…ط«ظ„ ظ…ظ„ظپط§طھ ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„ط£ط®ط±ظ‰ ظپظٹ ط§ظ„ظ…ط´ط±ظˆط¹)
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
            
            // ظ…ط²ط§ظ…ظ†ط© ط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ ظ…ط¹ UserDefaults ظ„ظ„ظ‚ط±ط§ط،ط© ط§ظ„ظ…طھط²ط§ظ…ظ†ط© ظ…ظ† ط§ظ„ظˆط­ط¯ط§طھ ط§ظ„ط£ط®ط±ظ‰
            UserDefaults.standard.set(newSettings.autoSaveSelfDestructingMedia, forKey: "joker_auto_save_media")
            UserDefaults.standard.set(newSettings.allow100Accounts, forKey: "joker_allow_100_accounts")
            UserDefaults.standard.set(newSettings.ghostMode, forKey: "joker_ghost_mode")
            UserDefaults.standard.set(newSettings.forcePremiumTranslation, forKey: "joker_force_premium_translation")
            UserDefaults.standard.set(newSettings.keepDeletedMessages, forKey: "joker_keep_deleted_messages")
            UserDefaults.standard.set(newSettings.requireChannelSubscription, forKey: "joker_require_subscription")
            UserDefaults.standard.set(newSettings.freezeLastSeen, forKey: "joker_freeze_last_seen")
            UserDefaults.standard.set(newSettings.bypassCopyProtection, forKey: "joker_bypass_copy_protection")
            UserDefaults.standard.synchronize()
            
            return SharedPreferencesEntry(newSettings)
        })
    }
}

// ط¯ط§ظ„ط© ظ„ط¬ظ„ط¨ ط¥ط¹ط¯ط§ط¯ط§طھ ط§ظ„ط¬ظˆظƒط± ط§ظ„ط­ط§ظ„ظٹط©
public func getJokerSettings(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<JokerSettings, NoError> {
    return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.jokerSettings])
    |> map { sharedData -> JokerSettings in
        if let entry = sharedData.entries[ApplicationSpecificSharedDataKeys.jokerSettings]?.get(JokerSettings.self) {
            return entry
        }
        return JokerSettings.defaultSettings
    }
}

// ط¯ط§ظ„ط© ظ„ظ„طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ظ‚ظ†ط§ط© @aljokeruserbot
public func checkJokerChannelSubscription(account: Account) -> Signal<Bool, NoError> {
    return Signal<Bool, NoError>.single(UserDefaults.standard.bool(forKey: "joker_channel_subscribed"))
}

// ط¯ط§ظ„ط© ظ„ط­ظپط¸ ط­ط§ظ„ط© ط§ظ„ط§ط´طھط±ط§ظƒ
public func saveJokerChannelSubscription(_ subscribed: Bool) {
    UserDefaults.standard.set(subscribed, forKey: "joker_channel_subscribed")
    UserDefaults.standard.synchronize()
}

// ط¯ط§ظ„ط© ظ„ظ„طھط­ظ‚ظ‚ ط¥ط°ط§ ظƒط§ظ†طھ ط§ظ„ظ…ظ…ظٹط²ط§طھ ظ…ظپط¹ظ„ط© (ظٹطھط·ظ„ط¨ ط§ظ„ط§ط´طھط±ط§ظƒ ظپظٹ ط§ظ„ظ‚ظ†ط§ط© ط¥ط°ط§ ظƒط§ظ† requireChannelSubscription=true)
public func areJokerFeaturesEnabled(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
    return getJokerSettings(accountManager: accountManager)
    |> map { settings -> Bool in
        if settings.requireChannelSubscription {
            return UserDefaults.standard.bool(forKey: "joker_channel_subscribed")
        }
        return true
    }
}

// ظ…ط¹ط±ظپ ط§ظ„ظ‚ظ†ط§ط© ط§ظ„ط¥ط¬ط¨ط§ط±ظٹ
public let jokerChannelUsername = "@aljokeruserbot"
public let jokerChannelLink = "https://t.me/aljokeruserbot"

// ط¯ط§ظ„ط© طھظˆط·ظٹظ† ط«ظ†ط§ط¦ظٹط© ط§ظ„ظ„ط؛ط©: طھط­ط¯ط¯ ظ„ط؛ط© ط§ظ„طھط·ط¨ظٹظ‚ ظ…ظ† ظ‚ظٹظ…ط© ط³ظ„ط³ظ„ط© ط¹ط§ظ…ط© ظ…ط¹ط±ظˆظپط© (ظ…ط«ظ„ Common_Back)
// طھظڈط³طھط®ط¯ظ… ظ„ط£ظ† ظ…ظپط§طھظٹط­ ط§ظ„ط¬ظˆظƒط± ط؛ظٹط± ظ…ظˆط¬ظˆط¯ط© ظپظٹ ط­ط²ظ… ط§ظ„ظ„ط؛ط§طھ ط§ظ„ط¨ط¹ظٹط¯ط© (طھط¸ظ„ ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹط© ط¥ظ† ظ„ظ… طھظڈطھط±ط¬ظ…)طŒ
// ظپظٹطھظ… ط§ط®طھظٹط§ط± ط§ظ„ظ†طµ ط§ظ„ط¹ط±ط¨ظٹ ظ„ظ„ط¹ط±ط¶ ط¹ظ†ط¯ ظˆط¬ظˆط¯ ط­ط±ظˆظپ ط¹ط±ط¨ظٹط© ظپظٹ ط§ظ„ط³ظ„ط³ظ„ط© ط§ظ„ظ…ط¹ظٹط§ط±ظٹط©.
public func jokerLocalize(sample: String, arValue: String, enValue: String) -> String {
    for scalar in sample.unicodeScalars {
        if (scalar.value >= 0x0600 && scalar.value <= 0x06FF) || (scalar.value >= 0x0750 && scalar.value <= 0x077F) || (scalar.value >= 0xFB50 && scalar.value <= 0xFDFF) {
            return arValue
        }
    }
    return enValue
}

// ط­ظ‚ظˆظ‚ ط§ظ„ظ…طµط¯ط±
public let jokerSourceCredits = "Source by @aljokeruserbot - Talogram Modified Version"
public let jokerSourceCreditsArabic = "ط§ظ„ظ…طµط¯ط± ط¨ظˆط§ط³ط·ط© @aljokeruserbot - ط¥طµط¯ط§ط± ظ…ط¹ط¯ظ„ ظ…ظ† Talogram"

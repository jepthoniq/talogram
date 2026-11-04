import Foundation
import TelegramCore
import SwiftSignalKit

// MARK: - Joker Channel Subscription Manager
// التحقق من الاشتراك في قناة @aljokeruserbot قبل تفعيل أي ميزة
// إذا لم يكن المستخدم مشتركاً، لا تظهر toggles للمميزات

public class JokerChannelSubscriptionManager {
    // معرف القناة الإجباري
    public static let channelUsername = "@aljokeruserbot"
    public static let channelLink = "https://t.me/aljokeruserbot"
    
    // مفتاح UserDefaults لحفظ حالة الاشتراك
    private static let subscriptionKey = "joker_channel_subscribed"
    
    // حفظ حالة الاشتراك
    public static func saveSubscriptionStatus(_ isSubscribed: Bool) {
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionKey)
        UserDefaults.standard.synchronize()
    }
    
    // جلب حالة الاشتراك المحفوظة
    public static func isSubscribed() -> Bool {
        return UserDefaults.standard.bool(forKey: subscriptionKey)
    }
    
    // التحقق من الاشتراك عبر API (يحتاج ربط مع TDLib channels.getParticipant)
    public static func checkSubscriptionViaAPI(account: Account) -> Signal<Bool, NoError> {
        return account.postbox.transaction { transaction -> Bool in
            // هذا Platzhalter - يمكن ربطه لاحقاً مع API الفعلي
            // للتحقق من مشاركة المستخدم في قناة @aljokeruserbot
            return UserDefaults.standard.bool(forKey: subscriptionKey)
        }
    }
    
    // عرض تنبيه يطلب من المستخدم الاشتراك في القناة
    public static func showSubscriptionRequiredAlert(context: AccountContext, present: @escaping (ViewController) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let alertController = AlertController(
            theme: presentationData.theme,
            title: presentationData.strings.JokerAlert_SubscriptionRequired_Title,
            text: presentationData.strings.JokerAlert_SubscriptionRequired_Text
        )
        
        alertController.addAction(AlertAction(type: .defaultAction, title: presentationData.strings.JokerAlert_SubscribeButton, action: { [weak alertController] _ in
            alertController?.dismissAnimated()
            if let url = URL(string: channelLink) {
                context.sharedContext.applicationContext.openUrl(url)
            }
        }))
        
        alertController.addAction(AlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: { [weak alertController] _ in
            alertController?.dismissAnimated()
        }))
        
        present(alertController)
    }
}

// دالة للتحقق إذا كانت الميزات مفعلة (تشترط الاشتراك)
public func areJokerFeaturesEnabled(accountManager: AccountManager<TelegramAccountManagerTypes>) -> Signal<Bool, NoError> {
    return accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.jokerSettings])
    |> map { sharedData -> Bool in
        if let entry = sharedData.entries[ApplicationSpecificSharedDataKeys.jokerSettings]?.get(JokerSettings.self) {
            if entry.requireChannelSubscription {
                return JokerChannelSubscriptionManager.isSubscribed()
            }
            return true
        }
        return false
    }
}

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
        let previousValue = UserDefaults.standard.object(forKey: subscriptionKey) as? Bool
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionKey)
        UserDefaults.standard.synchronize()
        if previousValue != isSubscribed {
            NotificationCenter.default.post(name: .jokerChannelSubscriptionDidChange, object: nil)
        }
    }
    
    // جلب حالة الاشتراك المحفوظة
    public static func isSubscribed() -> Bool {
        return UserDefaults.standard.bool(forKey: subscriptionKey)
    }
    
    // التحقق من الاشتراك عبر API (TDLib channels.getParticipant)
    public static func checkSubscriptionViaAPI(account: Account) -> Signal<Bool, NoError> {
        return JokerCoreHooks.checkChannelSubscription(network: account.network, username: self.channelUsername)
        |> map { isSubscribed -> Bool in
            self.saveSubscriptionStatus(isSubscribed)
            return isSubscribed
        }
    }
}

// MARK: - Reactive Subscription State
// حالة تفاعلية تستخدمها واجهة الجوكر (التبويب والإعدادات) حتى تتحول القائمة
// إلى شاشة "الاشتراك مطلوب" فور مغادرة القناة أو فشل التحقق.
public final class JokerChannelSubscriptionState {
    public static let shared = JokerChannelSubscriptionState()
    
    private let value: ValuePromise<Bool>
    private var observer: NSObjectProtocol?
    
    private init() {
        self.value = ValuePromise<Bool>(JokerChannelSubscriptionManager.isSubscribed(), ignoreRepeated: true)
        self.observer = nil
        self.observer = NotificationCenter.default.addObserver(forName: .jokerChannelSubscriptionDidChange, object: nil, queue: nil, using: { [weak self] _ in
            self?.value.set(JokerChannelSubscriptionManager.isSubscribed())
        })
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public var signal: Signal<Bool, NoError> {
        return self.value.get()
    }
    
    public var isSubscribed: Bool {
        return JokerChannelSubscriptionManager.isSubscribed()
    }
}

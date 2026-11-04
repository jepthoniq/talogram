import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

// MARK: - Joker Settings Controller
// شاشة إعدادات تعديلات الجوكر (Talogram) - تحتوي على تفعيل/تعطيل جميع المميزات
// تدعم اللغة العربية والإنجليزية حسب لغة التطبيق

private enum JokerSettingsControllerSection: Int32 {
    case channelSubscription
    case features
    case credits
}

private enum JokerSettingsControllerEntry: ItemListNodeEntry {
    case channelSubscriptionHeader(PresentationTheme, String)
    case channelSubscriptionInfo(PresentationTheme, String, String)
    case channelSubscribeButton(PresentationTheme, String, String)
    
    case featuresHeader(PresentationTheme, String)
    case autoSaveMediaToggle(PresentationTheme, String, String, Bool)
    case allow100AccountsToggle(PresentationTheme, String, String, Bool)
    case ghostModeToggle(PresentationTheme, String, String, Bool)
    case forcePremiumTranslationToggle(PresentationTheme, String, String, Bool)
    case keepDeletedMessagesToggle(PresentationTheme, String, String, Bool)
    case requireSubscriptionToggle(PresentationTheme, String, String, Bool)
    
    case creditsHeader(PresentationTheme, String)
    case creditsText(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
        case .channelSubscriptionHeader, .channelSubscriptionInfo, .channelSubscribeButton:
            return JokerSettingsControllerSection.channelSubscription.rawValue
        case .featuresHeader, .autoSaveMediaToggle, .allow100AccountsToggle, .ghostModeToggle, .forcePremiumTranslationToggle, .keepDeletedMessagesToggle, .requireSubscriptionToggle:
            return JokerSettingsControllerSection.features.rawValue
        case .creditsHeader, .creditsText:
            return JokerSettingsControllerSection.credits.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .channelSubscriptionHeader: return 0
        case .channelSubscriptionInfo: return 1
        case .channelSubscribeButton: return 2
        case .featuresHeader: return 10
        case .autoSaveMediaToggle: return 11
        case .allow100AccountsToggle: return 12
        case .ghostModeToggle: return 13
        case .forcePremiumTranslationToggle: return 14
        case .keepDeletedMessagesToggle: return 15
        case .requireSubscriptionToggle: return 16
        case .creditsHeader: return 20
        case .creditsText: return 21
        }
    }
    
    static func ==(lhs: JokerSettingsControllerEntry, rhs: JokerSettingsControllerEntry) -> Bool {
        switch lhs {
        case let .channelSubscriptionHeader(lhsTheme, lhsTitle):
            if case let .channelSubscriptionHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true }
        case let .channelSubscriptionInfo(lhsTheme, lhsTitle, lhsText):
            if case let .channelSubscriptionInfo(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText { return true }
        case let .channelSubscribeButton(lhsTheme, lhsTitle, lhsText):
            if case let .channelSubscribeButton(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText { return true }
        case let .featuresHeader(lhsTheme, lhsTitle):
            if case let .featuresHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true }
        case let .autoSaveMediaToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .autoSaveMediaToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .allow100AccountsToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .allow100AccountsToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .ghostModeToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .ghostModeToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .forcePremiumTranslationToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .forcePremiumTranslationToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .keepDeletedMessagesToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .keepDeletedMessagesToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .requireSubscriptionToggle(lhsTheme, lhsTitle, lhsText, lhsValue):
            if case let .requireSubscriptionToggle(rhsTheme, rhsTitle, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsValue == rhsValue { return true }
        case let .creditsHeader(lhsTheme, lhsTitle):
            if case let .creditsHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle { return true }
        case let .creditsText(lhsTheme, lhsTitle, lhsText):
            if case let .creditsText(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText { return true }
        default:
            return false
        }
        return false
    }
    
    static func <(lhs: JokerSettingsControllerEntry, rhs: JokerSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, context: AccountContext) -> ListViewItem {
        switch self {
        case let .channelSubscriptionHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, title: title, sectionId: self.section)
            
        case let .channelSubscriptionInfo(_, title, text):
            return ItemListTextItem(presentationData: presentationData, text: .plainText(text), sectionId: self.section)
            
        case let .channelSubscribeButton(_, title, text):
            return ItemListActionItem(presentationData: presentationData, title: title, text: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let url = URL(string: jokerChannelLink) {
                    context.sharedContext.applicationContext.openUrl(url)
                }
            })
            
        case let .featuresHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, title: title, sectionId: self.section)
            
        case let .autoSaveMediaToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedAutoSaveSelfDestructingMedia(newValue)
                }.startStandalone()
            })
            
        case let .allow100AccountsToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedAllow100Accounts(newValue)
                }.startStandalone()
            })
            
        case let .ghostModeToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedGhostMode(newValue)
                }.startStandalone()
            })
            
        case let .forcePremiumTranslationToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedForcePremiumTranslation(newValue)
                }.startStandalone()
            })
            
        case let .keepDeletedMessagesToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedKeepDeletedMessages(newValue)
                }.startStandalone()
            })
            
        case let .requireSubscriptionToggle(_, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, text: text, value: value, disableLeadingInset: true, sectionId: self.section, style: .blocks, updated: { newValue in
                let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager) { settings in
                    settings.withUpdatedRequireChannelSubscription(newValue)
                }.startStandalone()
            })
            
        case let .creditsHeader(_, title):
            return ItemListSectionHeaderItem(presentationData: presentationData, title: title, sectionId: self.section)
            
        case let .creditsText(_, title, text):
            return ItemListTextItem(presentationData: presentationData, text: .plainText(text), sectionId: self.section)
        }
    }
}

private func jokerSettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, settings: JokerSettings, context: AccountContext) -> [JokerSettingsControllerEntry] {
    var entries: [JokerSettingsControllerEntry] = []
    
    // القسم الأول: الاشتراك في القناة
    entries.append(.channelSubscriptionHeader(theme, strings.JokerSettings_ChannelSubscription_Header))
    entries.append(.channelSubscriptionInfo(theme, strings.JokerSettings_ChannelSubscription_Title, strings.JokerSettings_ChannelSubscription_Text))
    entries.append(.channelSubscribeButton(theme, strings.JokerSettings_SubscribeButton, strings.JokerSettings_SubscribeButtonText))
    
    // القسم الثاني: المميزات
    entries.append(.featuresHeader(theme, strings.JokerSettings_Features_Header))
    entries.append(.autoSaveMediaToggle(theme, strings.JokerSettings_AutoSaveMedia_Title, strings.JokerSettings_AutoSaveMedia_Text, settings.autoSaveSelfDestructingMedia))
    entries.append(.allow100AccountsToggle(theme, strings.JokerSettings_Allow100Accounts_Title, strings.JokerSettings_Allow100Accounts_Text, settings.allow100Accounts))
    entries.append(.ghostModeToggle(theme, strings.JokerSettings_GhostMode_Title, strings.JokerSettings_GhostMode_Text, settings.ghostMode))
    entries.append(.forcePremiumTranslationToggle(theme, strings.JokerSettings_ForcePremiumTranslation_Title, strings.JokerSettings_ForcePremiumTranslation_Text, settings.forcePremiumTranslation))
    entries.append(.keepDeletedMessagesToggle(theme, strings.JokerSettings_KeepDeletedMessages_Title, strings.JokerSettings_KeepDeletedMessages_Text, settings.keepDeletedMessages))
    entries.append(.requireSubscriptionToggle(theme, strings.JokerSettings_RequireSubscription_Title, strings.JokerSettings_RequireSubscription_Text, settings.requireChannelSubscription))
    
    // القسم الثالث: الحقوق
    entries.append(.creditsHeader(theme, strings.JokerSettings_Credits_Header))
    entries.append(.creditsText(theme, strings.JokerSettings_Credits_Title, strings.JokerSettings_Credits_Text))
    
    return entries
}

public class JokerSettingsController: ViewController {
    private let context: AccountContext
    private var settingsDisposable: Disposable?
    
    public init(context: AccountContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)
        
        self.title = context.sharedContext.currentPresentationData.with { $0 }.strings.JokerSettings_Title
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.settingsDisposable?.dispose()
    }
    
    public override func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.settingsDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).startStandalone(next: { [weak self] presentationData in
            guard let strongSelf = self else { return }
            
            strongSelf.navigationItem.backBarButtonItem = UIBarButtonItem(title: presentationData.strings.Navigation_Back, style: .plain, target: nil, action: nil)
            
            let controllerNode = JokerSettingsControllerNode(context: strongSelf.context, presentationData: presentationData)
            strongSelf.displayNode = controllerNode
        })
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        if let controllerNode = self.displayNode as? JokerSettingsControllerNode {
            controllerNode.containerLayoutUpdated(layout, transition: transition)
        }
    }
}

private final class JokerSettingsControllerNode: ASDisplayNode, ASScrollViewDelegate {
    private let context: AccountContext
    private let presentationData: PresentationData
    
    private var itemsNode: ItemListNode
    private var settingsDisposable: Disposable?
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        self.itemsNode = ItemListNode(theme: presentationData.theme, plainStyle: true)
        
        super.init()
        
        self.addSubnode(self.itemsNode)
        
        self.loadSettings()
    }
    
    deinit {
        self.settingsDisposable?.dispose()
    }
    
    private func loadSettings() {
        let accountManager = self.context.sharedContext.accountManager
        
        self.settingsDisposable = getJokerSettings(accountManager: accountManager).startStandalone(next: { [weak self] settings in
            guard let strongSelf = self else { return }
            
            let entries = jokerSettingsControllerEntries(
                theme: strongSelf.presentationData.theme,
                strings: strongSelf.presentationData.strings,
                settings: settings,
                context: strongSelf.context
            )
            
            strongSelf.itemsNode.transaction(deleteItems: [], insertItems: entries, updateItems: [], beforeItem: nil, withAnimation: .None, transition: .immediate, { _ in })
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.itemsNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.itemsNode.containerLayoutUpdated(layout, transition: transition)
    }
}

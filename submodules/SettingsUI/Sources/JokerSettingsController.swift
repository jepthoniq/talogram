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
// شاشة إعدادات تعديلات الجوكر (Talogram) — تفعيل/تعطيل جميع المميزات
// مكتوبة بالنمط الحديث (function factory) المطابق لواجهات ItemListUI الحالية

private final class JokerSettingsControllerArguments {
    let updateAutoSaveMedia: (Bool) -> Void
    let updateAllow100Accounts: (Bool) -> Void
    let updateGhostMode: (Bool) -> Void
    let updateForcePremiumTranslation: (Bool) -> Void
    let updateKeepDeletedMessages: (Bool) -> Void
    let updateRequireSubscription: (Bool) -> Void
    let openChannel: () -> Void
    
    init(
        updateAutoSaveMedia: @escaping (Bool) -> Void,
        updateAllow100Accounts: @escaping (Bool) -> Void,
        updateGhostMode: @escaping (Bool) -> Void,
        updateForcePremiumTranslation: @escaping (Bool) -> Void,
        updateKeepDeletedMessages: @escaping (Bool) -> Void,
        updateRequireSubscription: @escaping (Bool) -> Void,
        openChannel: @escaping () -> Void
    ) {
        self.updateAutoSaveMedia = updateAutoSaveMedia
        self.updateAllow100Accounts = updateAllow100Accounts
        self.updateGhostMode = updateGhostMode
        self.updateForcePremiumTranslation = updateForcePremiumTranslation
        self.updateKeepDeletedMessages = updateKeepDeletedMessages
        self.updateRequireSubscription = updateRequireSubscription
        self.openChannel = openChannel
    }
}

private enum JokerSettingsControllerSection: Int32 {
    case channelSubscription
    case features
    case credits
}

private enum JokerSettingsControllerEntry: ItemListNodeEntry {
    case channelSubscriptionHeader(String)
    case channelSubscriptionInfo(String)
    case channelSubscribeButton(String)
    
    case featuresHeader(String)
    case autoSaveMediaToggle(String, String, Bool)
    case allow100AccountsToggle(String, String, Bool)
    case ghostModeToggle(String, String, Bool)
    case forcePremiumTranslationToggle(String, String, Bool)
    case keepDeletedMessagesToggle(String, String, Bool)
    case requireSubscriptionToggle(String, String, Bool)
    
    case creditsHeader(String)
    case creditsText(String)
    
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
        case .channelSubscriptionHeader:
            return 0
        case .channelSubscriptionInfo:
            return 1
        case .channelSubscribeButton:
            return 2
        case .featuresHeader:
            return 10
        case .autoSaveMediaToggle:
            return 11
        case .allow100AccountsToggle:
            return 12
        case .ghostModeToggle:
            return 13
        case .forcePremiumTranslationToggle:
            return 14
        case .keepDeletedMessagesToggle:
            return 15
        case .requireSubscriptionToggle:
            return 16
        case .creditsHeader:
            return 20
        case .creditsText:
            return 21
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! JokerSettingsControllerArguments
        switch self {
        case let .channelSubscriptionHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .channelSubscriptionInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .channelSubscribeButton(title):
            return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openChannel()
            })
        case let .featuresHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .autoSaveMediaToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAutoSaveMedia(value)
            })
        case let .allow100AccountsToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAllow100Accounts(value)
            })
        case let .ghostModeToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateGhostMode(value)
            })
        case let .forcePremiumTranslationToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateForcePremiumTranslation(value)
            })
        case let .keepDeletedMessagesToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateKeepDeletedMessages(value)
            })
        case let .requireSubscriptionToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateRequireSubscription(value)
            })
        case let .creditsHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .creditsText(text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

private func jokerSettingsControllerEntries(presentationData: PresentationData, settings: JokerSettings) -> [JokerSettingsControllerEntry] {
    var entries: [JokerSettingsControllerEntry] = []
    
    // القسم الأول: الاشتراك في القناة
    entries.append(.channelSubscriptionHeader(presentationData.strings.JokerSettings_ChannelSubscription_Header))
    entries.append(.channelSubscriptionInfo(presentationData.strings.JokerSettings_ChannelSubscription_Text))
    entries.append(.channelSubscribeButton(presentationData.strings.JokerSettings_SubscribeButton))
    
    // القسم الثاني: المميزات
    entries.append(.featuresHeader(presentationData.strings.JokerSettings_Features_Header))
    entries.append(.autoSaveMediaToggle(presentationData.strings.JokerSettings_AutoSaveMedia_Title, presentationData.strings.JokerSettings_AutoSaveMedia_Text, settings.autoSaveSelfDestructingMedia))
    entries.append(.allow100AccountsToggle(presentationData.strings.JokerSettings_Allow100Accounts_Title, presentationData.strings.JokerSettings_Allow100Accounts_Text, settings.allow100Accounts))
    entries.append(.ghostModeToggle(presentationData.strings.JokerSettings_GhostMode_Title, presentationData.strings.JokerSettings_GhostMode_Text, settings.ghostMode))
    entries.append(.forcePremiumTranslationToggle(presentationData.strings.JokerSettings_ForcePremiumTranslation_Title, presentationData.strings.JokerSettings_ForcePremiumTranslation_Text, settings.forcePremiumTranslation))
    entries.append(.keepDeletedMessagesToggle(presentationData.strings.JokerSettings_KeepDeletedMessages_Title, presentationData.strings.JokerSettings_KeepDeletedMessages_Text, settings.keepDeletedMessages))
    entries.append(.requireSubscriptionToggle(presentationData.strings.JokerSettings_RequireSubscription_Title, presentationData.strings.JokerSettings_RequireSubscription_Text, settings.requireChannelSubscription))
    
    // القسم الثالث: الحقوق
    entries.append(.creditsHeader(presentationData.strings.JokerSettings_Credits_Header))
    entries.append(.creditsText(presentationData.strings.JokerSettings_Credits_Text))
    
    return entries
}

public func jokerSettingsController(context: AccountContext) -> ViewController {
    var openChannelImpl: (() -> Void)? = nil
    
    let arguments = JokerSettingsControllerArguments(
        updateAutoSaveMedia: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedAutoSaveSelfDestructingMedia(value) }).start()
        },
        updateAllow100Accounts: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedAllow100Accounts(value) }).start()
        },
        updateGhostMode: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedGhostMode(value) }).start()
        },
        updateForcePremiumTranslation: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedForcePremiumTranslation(value) }).start()
        },
        updateKeepDeletedMessages: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedKeepDeletedMessages(value) }).start()
        },
        updateRequireSubscription: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedRequireChannelSubscription(value) }).start()
        },
        openChannel: {
            openChannelImpl?()
        }
    )
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        getJokerSettings(accountManager: context.sharedContext.accountManager)
    )
    |> deliverOnMainQueue
    |> map { presentationData, jokerSettings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.JokerSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: jokerSettingsControllerEntries(presentationData: presentationData, settings: jokerSettings), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    
    openChannelImpl = { [weak controller] in
        guard let controller, let navigationController = controller.navigationController as? NavigationController else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: JokerChannelSubscriptionManager.channelLink, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {
        })
    }
    
    return controller
}

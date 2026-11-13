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

private final class JokerSettingsControllerArguments {
    let updateAutoSaveMedia: (Bool) -> Void
    let updateAllow100Accounts: (Bool) -> Void
    let updateGhostMode: (Bool) -> Void
    let updateForcePremiumTranslation: (Bool) -> Void
    let updateKeepDeletedMessages: (Bool) -> Void
    let updateFreezeLastSeen: (Bool) -> Void
    let updateBypassCopyProtection: (Bool) -> Void
    let updateStoryStealthMode: (Bool) -> Void
    let updateCallRecording: (Bool) -> Void
    let updateVoiceToText: (Bool) -> Void
    let updateSecretChatTools: (Bool) -> Void
    let openBusinessQuickReplies: () -> Void

    init(
        updateAutoSaveMedia: @escaping (Bool) -> Void,
        updateAllow100Accounts: @escaping (Bool) -> Void,
        updateGhostMode: @escaping (Bool) -> Void,
        updateForcePremiumTranslation: @escaping (Bool) -> Void,
        updateKeepDeletedMessages: @escaping (Bool) -> Void,
        updateFreezeLastSeen: @escaping (Bool) -> Void,
        updateBypassCopyProtection: @escaping (Bool) -> Void,
        updateStoryStealthMode: @escaping (Bool) -> Void,
        updateCallRecording: @escaping (Bool) -> Void,
        updateVoiceToText: @escaping (Bool) -> Void,
        updateSecretChatTools: @escaping (Bool) -> Void,
        openBusinessQuickReplies: @escaping () -> Void
    ) {
        self.updateAutoSaveMedia = updateAutoSaveMedia
        self.updateAllow100Accounts = updateAllow100Accounts
        self.updateGhostMode = updateGhostMode
        self.updateForcePremiumTranslation = updateForcePremiumTranslation
        self.updateKeepDeletedMessages = updateKeepDeletedMessages
        self.updateFreezeLastSeen = updateFreezeLastSeen
        self.updateBypassCopyProtection = updateBypassCopyProtection
        self.updateStoryStealthMode = updateStoryStealthMode
        self.updateCallRecording = updateCallRecording
        self.updateVoiceToText = updateVoiceToText
        self.updateSecretChatTools = updateSecretChatTools
        self.openBusinessQuickReplies = openBusinessQuickReplies
    }
}

private enum JokerSettingsControllerSection: Int32 {
    case features
    case business
    case credits
}

private func jokerLocalized(_ presentationData: PresentationData, _ arValue: String, _ enValue: String) -> String {
    return jokerLocalize(sample: presentationData.strings.Common_Back, arValue: arValue, enValue: enValue)
}

private enum JokerSettingsControllerEntry: ItemListNodeEntry {
    case featuresHeader(String)
    case autoSaveMediaToggle(String, String, Bool)
    case allow100AccountsToggle(String, String, Bool)
    case ghostModeToggle(String, String, Bool)
    case forcePremiumTranslationToggle(String, String, Bool)
    case freezeLastSeenToggle(String, String, Bool)
    case bypassCopyProtectionToggle(String, String, Bool)
    case keepDeletedMessagesToggle(String, String, Bool)
    case storyStealthModeToggle(String, String, Bool)
    case callRecordingToggle(String, String, Bool)
    case voiceToTextToggle(String, String, Bool)
    case secretChatToolsToggle(String, String, Bool)

    case businessHeader(String)
    case businessQuickReplies(String, String)

    case creditsHeader(String)
    case creditsText(String)

    var section: ItemListSectionId {
        switch self {
        case .featuresHeader, .autoSaveMediaToggle, .allow100AccountsToggle, .ghostModeToggle, .forcePremiumTranslationToggle, .freezeLastSeenToggle, .bypassCopyProtectionToggle, .keepDeletedMessagesToggle, .storyStealthModeToggle, .callRecordingToggle, .voiceToTextToggle, .secretChatToolsToggle:
            return JokerSettingsControllerSection.features.rawValue
        case .businessHeader, .businessQuickReplies:
            return JokerSettingsControllerSection.business.rawValue
        case .creditsHeader, .creditsText:
            return JokerSettingsControllerSection.credits.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
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
        case .freezeLastSeenToggle:
            return 15
        case .bypassCopyProtectionToggle:
            return 16
        case .keepDeletedMessagesToggle:
            return 17
        case .storyStealthModeToggle:
            return 21
        case .callRecordingToggle:
            return 24
        case .voiceToTextToggle:
            return 25
        case .secretChatToolsToggle:
            return 26
        case .businessHeader:
            return 18
        case .businessQuickReplies:
            return 20
        case .creditsHeader:
            return 22
        case .creditsText:
            return 23
        }
    }

    static func <(lhs: JokerSettingsControllerEntry, rhs: JokerSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! JokerSettingsControllerArguments
        switch self {
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
        case let .freezeLastSeenToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateFreezeLastSeen(value)
            })
        case let .bypassCopyProtectionToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateBypassCopyProtection(value)
            })
        case let .keepDeletedMessagesToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateKeepDeletedMessages(value)
            })
        case let .storyStealthModeToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateStoryStealthMode(value)
            })
        case let .callRecordingToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateCallRecording(value)
            })
        case let .voiceToTextToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateVoiceToText(value)
            })
        case let .secretChatToolsToggle(title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateSecretChatTools(value)
            })
        case let .businessHeader(title):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
        case let .businessQuickReplies(title, text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: nil, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: {
                arguments.openBusinessQuickReplies()
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

    entries.append(.featuresHeader(jokerLocalized(presentationData, "مميزات الجوكر", "Joker Features")))
    entries.append(.autoSaveMediaToggle(jokerLocalized(presentationData, "حفظ الوسائط ذاتية التدمير تلقائياً", "Auto Save Self-Destructing Media"), jokerLocalized(presentationData, "حفظ الصور والفيديوهات والرسائل الصوتية ذاتية التدمير في الرسائل المحفوظة تلقائياً عند فتحها", "Automatically save self-destructing photos, videos, and voice messages to Saved Messages when opened."), settings.autoSaveSelfDestructingMedia))
    entries.append(.allow100AccountsToggle(jokerLocalized(presentationData, "السماح حتى 100 حساب", "Allow 100 Accounts"), jokerLocalized(presentationData, "السماح بأضافة حتى 100 حساب في التطبيق", "Allow adding up to 100 accounts in the app."), settings.allow100Accounts))
    entries.append(.ghostModeToggle(jokerLocalized(presentationData, "وضع الشبح", "Ghost Mode"), jokerLocalized(presentationData, "اخفاء علامات قراءة الرسائل يعني المستخدم مايدري بيك انت شفت الرسالة", "Hide read receipts with an eye icon at the top of the chat next to the chat title."), settings.ghostMode))
    entries.append(.forcePremiumTranslationToggle(jokerLocalized(presentationData, "ترجمة البريميوم مجاناً", "Force Premium Translation"), jokerLocalized(presentationData, "تفعيل ميزة الترجمة الخاصة بالبريميوم مجاناً في المحادثات والقنوات.", "Enable the Premium translation feature for free in chats and channels."), settings.forcePremiumTranslation))
    entries.append(.freezeLastSeenToggle(jokerLocalized(presentationData, "تجميد آخر ظهور", "Freeze Last Seen"), jokerLocalized(presentationData, "إخفاء حالة آخر ظهور الخاصة بك وعدم ارسال تحديثات الحضور الى الخادم", "Hide your last seen status and stop sending presence updates to the server."), settings.freezeLastSeen))
    entries.append(.bypassCopyProtectionToggle(jokerLocalized(presentationData, "تجاوز حماية المحتوى", "Bypass Copy Protection"), jokerLocalized(presentationData, "تجاوز قيود حماية النسخ في القنوات المحمية وحفظ الصور، وإعادة توجيه الرسالة بالكامل", "Bypass copy protection in protected channels: copy captions, save images, and forward the full message (image with caption)."), settings.bypassCopyProtection))
    entries.append(.keepDeletedMessagesToggle(jokerLocalized(presentationData, "الاحتفاظ بالرسائل المحذوفة", "Keep Deleted Messages"), jokerLocalized(presentationData, "الاحتفاظ بالرسائل المحذوفة في المحادثة", "Keep deleted messages locally with an 'x' mark next to the bubble. Clearing history deletes everything permanently."), settings.keepDeletedMessages))
    entries.append(.storyStealthModeToggle(jokerLocalized(presentationData, "تجميد مشاهدة الستوريات", "Freeze Story Views"), jokerLocalized(presentationData, "شاهد ستوريات الآخرين دون ظهورك في قائمة المشاهدين.", "View other people’s stories without appearing in their viewers list. Works entirely on your device — no subscription, no Telegram Business."), settings.storyStealthMode))
    entries.append(.callRecordingToggle(jokerLocalized(presentationData, "تسجيل المكالمات", "Call Recording"), jokerLocalized(presentationData, "إظهار زر التسجيل الدائري في شاشة المكالمة لحفظ الصوت محليًا في الرسائل المحفوظة مثل ملف ميرج (ميكروفون + الطرف الآخر)", "Show the circular recording button on the call screen and save a merged local recording (mic + other side) to Saved Messages"), settings.callRecording))
    entries.append(.voiceToTextToggle(jokerLocalized(presentationData, "تحويل الصوت إلى نص", "Voice-to-Text Transcription"), jokerLocalized(presentationData, "فتح ميزة تيليجرام بريميوم لتحويل الرسائل الصوتية إلى نص مجاناً وعلى الجهاز مباشرة، بدون حد للرسائل ودون اشتراك", "Unlock the Premium feature that transcribes voice messages to text for free, on-device, with no message limit and no subscription"), settings.voiceToText))
    entries.append(.secretChatToolsToggle(jokerLocalized(presentationData, "أدوات المحادثات السرية", "Secret Chat Tools"), jokerLocalized(presentationData, "حفظ الصور والفيديوهات والملفات والرسائل من المحادثات السرية وإرسالها بنسخة محلية بدون خادم، وإخفاء رسالة «تم التقاط السكرين» عن الطرف الآخر — كل شيء محلي على جهازك", "Save photos, videos, files and messages from secret chats and forward them as a local copy (no server involvement), and hide the screenshot notification from the other party — everything stays on your device"), settings.secretChatTools))

    entries.append(.businessHeader(jokerLocalized(presentationData, "ميزات محلية", "Local Features")))
    entries.append(.businessQuickReplies(jokerLocalized(presentationData, "ردود سريعة", "Local Quick Replies"), jokerLocalized(presentationData, "أنشئ وأدر ردودًا سريعة على هذا الجهاز", "Create and manage local quick replies on this device. Not Telegram Business.")))

    entries.append(.creditsHeader(jokerLocalized(presentationData, "حقوق المصدر", "Source Credits")))
    entries.append(.creditsText(jokerLocalized(presentationData, "- المصدر بواسطة @aljokeruserbot", "Talogram Modified Version - Source by @aljokeruserbot")))

    return entries
}

public func jokerSettingsController(context: AccountContext, isTab: Bool = false) -> ViewController {
    var settingsController: ViewController! = nil
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
            // Joker Mod: switching the free "Real-Time Translation" option on/off also switches the chat translation
            // setting, so the translation panel appears in chats and channels right away (and messages translate).
            let _ = updateTranslationSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedTranslateChats(value) }).start()
        },
        updateKeepDeletedMessages: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedKeepDeletedMessages(value) }).start()
        },
        updateFreezeLastSeen: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedFreezeLastSeen(value) }).start()
        },
        updateBypassCopyProtection: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedBypassCopyProtection(value) }).start()
        },
        updateStoryStealthMode: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedStoryStealthMode(value) }).start()
        },
        updateCallRecording: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedCallRecording(value) }).start()
        },
        updateVoiceToText: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedVoiceToText(value) }).start()
        },
        updateSecretChatTools: { value in
            let _ = updateJokerSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedSecretChatTools(value) }).start()
        },
        openBusinessQuickReplies: {
            guard let settingsController else {
                return
            }
            let controller = JokerLocalQuickRepliesController(context: context)
            settingsController.push(controller)
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

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(jokerLocalized(presentationData, "إعدادات الجوكر", "Joker Settings")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: isTab ? nil : ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: jokerSettingsControllerEntries(presentationData: presentationData, settings: jokerSettings), style: .blocks, animateChanges: true)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = isTab ? .default : .modal
    settingsController = controller

    return controller
}

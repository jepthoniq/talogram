import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TextFormat
import UndoUI

// Joker Mod: forwarding secret chat messages to another chat, fully client-side.
// The Telegram server refuses to forward secret-chat messages (the whole point of
// secret chats), so the normal `messages.forwardMessages` call fails. Instead the
// media bytes already held locally are re-uploaded into the target chat as brand-new
// media and the text is re-sent as regular text. Nothing touches the secret chat's
// protected channel other than the ordinary salts the client would use anyway.
extension ChatControllerImpl {
    private func jokerSecretChatCopyJobs(secretMessages: [EngineRawMessage], messageText: NSAttributedString) -> Signal<[EnqueueMessage], NoError> {
        var jobs: [Signal<EnqueueMessage?, NoError>] = []

        for message in secretMessages {
            let captionEntities = (message.attributes.first(where: { $0 is TextEntitiesMessageAttribute }) as? TextEntitiesMessageAttribute)?.entities ?? []
            let captionAttributes: [EngineMessage.Attribute] = captionEntities.isEmpty ? [] : [TextEntitiesMessageAttribute(entities: captionEntities)]

            if !message.text.isEmpty {
                jobs.append(.single(EnqueueMessage.message(text: message.text, attributes: captionAttributes, inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])))
            }

            for media in message.media {
                switch media {
                case let image as TelegramMediaImage:
                    // Re-upload the decrypted image bytes held in the media box.
                    guard let representation = largestImageRepresentation(image.representations) else {
                        continue
                    }
                    let resource = representation.resource
                    let dimensions = representation.dimensions
                    let captionText = message.text
                    jobs.append((self.context.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: true))
                    |> take(1))
                    |> mapToSignal { data -> Signal<EnqueueMessage?, NoError> in
                        guard data.complete, let bytes = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                            return .single(nil)
                        }
                        return standaloneUploadedImage(postbox: self.context.account.postbox, network: self.context.account.network, peerId: self.context.account.peerId, text: "", source: .data(bytes), thumbnailData: nil, dimensions: dimensions)
                        |> map { event -> EnqueueMessage? in
                            guard case let .result(result) = event, case let .media(reference) = result else {
                                return nil
                            }
                            return .message(text: captionText, attributes: captionAttributes, inlineStickers: [:], mediaReference: .standalone(media: reference), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                        }
                        |> `catch` { _ in
                            return .single(nil)
                        }
                    })

                case let file as TelegramMediaFile:
                    // Files (videos, voice messages, music, documents, GIFs) go the same route;
                    // the original attributes keep them playable in the target chat.
                    let resource = file.resource
                    let mimeType = file.mimeType
                    let fileAttributes = file.attributes
                    let hintFileIsLarge = (file.size ?? 0) > 10 * 1024 * 1024
                    let captionText = message.text
                    jobs.append((self.context.account.postbox.mediaBox.resourceData(resource, option: .complete(waitUntilFetchStatus: true))
                    |> take(1))
                    |> mapToSignal { data -> Signal<EnqueueMessage?, NoError> in
                        guard data.complete, let bytes = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                            return .single(nil)
                        }
                        return standaloneUploadedFile(postbox: self.context.account.postbox, network: self.context.account.network, peerId: self.context.account.peerId, text: "", source: .data(bytes), thumbnailData: nil, mimeType: mimeType, attributes: fileAttributes, hintFileIsLarge: hintFileIsLarge)
                        |> map { event -> EnqueueMessage? in
                            guard case let .result(result) = event, case let .media(reference) = result else {
                                return nil
                            }
                            return .message(text: captionText, attributes: captionAttributes, inlineStickers: [:], mediaReference: .standalone(media: reference), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                        }
                        |> `catch` { _ in
                            return .single(nil)
                        }
                    })

                default:
                    continue
                }
            }
        }

        var result: [EnqueueMessage] = []
        let messageTextString = messageText.string
        if messageTextString.count > 0 {
            let inputText = convertMarkdownToAttributes(messageText)
            let trimmed = trimChatInputText(inputText)
            if trimmed.length != 0 {
                let entities = generateChatInputTextEntities(trimmed, generateLinks: true)
                var attributes: [EngineMessage.Attribute] = []
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
                result.append(.message(text: trimmed.string, attributes: attributes, inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
            }
        }

        if jobs.isEmpty {
            return .single(result)
        }
        return combineLatest(jobs)
        |> map { jobResults -> [EnqueueMessage] in
            var output = result
            for item in jobResults {
                if let item {
                    output.append(item)
                }
            }
            return output
        }
    }

    private func jokerSecretChatForwardEnqueueMessages(account: Account, secretMessages: [EngineRawMessage], messageText: NSAttributedString, peerIds: [EnginePeer.Id]) {
        guard !peerIds.isEmpty else {
            return
        }
        for peerId in peerIds {
            let targetPeerId = peerId
            let _ = (self.jokerSecretChatCopyJobs(secretMessages: secretMessages, messageText: messageText)
            |> deliverOnMainQueue).startStandalone(next: { enqueued in
                guard !enqueued.isEmpty else {
                    return
                }
                let _ = enqueueMessages(account: account, peerId: targetPeerId, messages: enqueued).startStandalone()
            })
        }
    }

    func forwardSecretChatMessagesAsCopy(messages: [EngineRawMessage]) {
        let context = self.context
        let account = context.account
        let filter: ChatListNodePeersFilter = [.onlyWriteable, .excludeDisabled, .doNotSearchMessages]
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, updatedPresentationData: self.updatedPresentationData, filter: filter, hasFilters: true, attemptSelection: nil, multipleSelection: true, forwardedMessageIds: messages.map { $0.id }, selectForumThreads: true))

        controller.multiplePeersSelected = { [weak self, weak controller] peers, _, messageText, _, _, _ in
            guard let strongSelf = self else {
                return
            }
            controller?.dismiss()
            strongSelf.jokerSecretChatForwardEnqueueMessages(account: account, secretMessages: messages, messageText: messageText, peerIds: peers.map { $0.id })

            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: text), elevatedLayout: false, position: .bottom, animateInAsReplacement: true, action: { _ in
                return false
            }), in: .current)
        }

        controller.peerSelected = { [weak self, weak controller] peer, _ in
            guard let strongSelf = self else {
                return
            }
            controller?.dismiss()
            let targetPeerId = peer.id
            strongSelf.jokerSecretChatForwardEnqueueMessages(account: account, secretMessages: messages, messageText: NSAttributedString(), peerIds: [targetPeerId])

            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let singleText: String
            if let statPeer = peer as? EnginePeer {
                singleText = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(statPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(statPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")).string
            } else {
                singleText = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
            }
            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: singleText), elevatedLayout: false, position: .bottom, animateInAsReplacement: true, action: { _ in
                return false
            }), in: .current)
        }

        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(controller)
    }
}

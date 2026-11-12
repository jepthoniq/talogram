import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import LocalMediaResources
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
                    // Re-upload the decrypted image bytes held in the media box as a local image.
                    guard let representation = largestImageRepresentation(image.representations) else {
                        continue
                    }
                    let dimensions = representation.dimensions
                    let captionText = message.text
                    jobs.append((context.engine.resources.data(resource: EngineMediaResource(representation.resource), waitUntilFetchStatus: true)
                    |> take(1))
                    |> map { data -> EnqueueMessage? in
                        guard data.isComplete else {
                            return nil
                        }
                        let randomId = Int64.random(in: Int64.min ... Int64.max)
                        let resource = LocalFileReferenceMediaResource(localFilePath: data.path, randomId: randomId)
                        let representation = TelegramMediaImageRepresentation(
                            dimensions: dimensions,
                            resource: resource,
                            progressiveSizes: [],
                            immediateThumbnailData: nil,
                            hasVideo: false,
                            isPersonal: false
                        )
                        let outImage = TelegramMediaImage(
                            imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: randomId),
                            representations: [representation],
                            immediateThumbnailData: nil,
                            reference: nil,
                            partialReference: nil,
                            flags: []
                        )
                        return .message(text: captionText, attributes: captionAttributes, inlineStickers: [:], mediaReference: .standalone(media: outImage), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                    })

                case let file as TelegramMediaFile:
                    // Files (videos, voice messages, music, documents, GIFs) go the same route;
                    // the original attributes keep them playable in the target chat.
                    let fileAttributes = file.attributes
                    let mimeType = file.mimeType
                    let fileSize: Int64? = file.size
                    let captionText = message.text
                    jobs.append((context.engine.resources.data(resource: EngineMediaResource(file.resource), waitUntilFetchStatus: true)
                    |> take(1))
                    |> map { data -> EnqueueMessage? in
                        guard data.isComplete else {
                            return nil
                        }
                        let randomId = Int64.random(in: Int64.min ... Int64.max)
                        var attributes: [TelegramMediaFileAttribute] = [.FileName(fileName: (data.path as NSString).lastPathComponent)]
                        attributes.append(contentsOf: fileAttributes.filter { attribute in
                            if case .FileName = attribute {
                                return false
                            }
                            return true
                        })
                        let resource = LocalFileVideoMediaResource(randomId: randomId, path: data.path, adjustments: nil)
                        let outFile = TelegramMediaFile(
                            fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: randomId),
                            partialReference: nil,
                            resource: resource,
                            previewRepresentations: [],
                            videoThumbnails: [],
                            videoCover: nil,
                            immediateThumbnailData: nil,
                            mimeType: mimeType,
                            size: fileSize,
                            attributes: attributes,
                            alternativeRepresentations: []
                        )
                        return .message(text: captionText, attributes: captionAttributes, inlineStickers: [:], mediaReference: .standalone(media: outFile), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
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
            if peer.id == strongSelf.context.account.peerId {
                singleText = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
            } else {
                let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")
                singleText = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
            }
            strongSelf.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: singleText), elevatedLayout: false, position: .bottom, animateInAsReplacement: true, action: { _ in
                return false
            }), in: .current)
        }

        self.chatDisplayNode.dismissInput()
        self.effectiveNavigationController?.pushViewController(controller)
    }
}

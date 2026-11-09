import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalMediaResources
import ChatInterfaceState
import ChatPresentationInterfaceState
import AccountContext

extension ChatControllerImpl {
    func sendLocalQuickReply(id: String) {
        guard let reply = getJokerLocalQuickReplies().first(where: { $0.id == id }) else {
            return
        }
        self.sendLocalQuickReply(reply: reply)
    }

    private func makeLocalQuickReplyMedia(_ media: JokerQuickReplyMedia) -> EngineMedia? {
        let fileURL = jokerQuickReplyMediaURL(fileName: media.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        if media.isVideo {
            var attributes: [TelegramMediaFileAttribute] = []
            attributes.append(.FileName(fileName: media.fileName))
            attributes.append(.Video(duration: media.duration, size: PixelDimensions(width: media.width, height: media.height), flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil))
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value
            let resource = LocalFileVideoMediaResource(randomId: randomId, path: fileURL.path, adjustments: nil)
            let file = TelegramMediaFile(
                fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: randomId),
                partialReference: nil,
                resource: resource,
                previewRepresentations: [],
                videoThumbnails: [],
                videoCover: nil,
                immediateThumbnailData: nil,
                mimeType: media.mimeType,
                size: fileSize,
                attributes: attributes,
                alternativeRepresentations: []
            )
            return .file(file)
        } else {
            let resource = LocalFileReferenceMediaResource(localFilePath: fileURL.path, randomId: randomId)
            let representation = TelegramMediaImageRepresentation(
                dimensions: PixelDimensions(width: media.width, height: media.height),
                resource: resource,
                progressiveSizes: [],
                immediateThumbnailData: nil,
                hasVideo: false,
                isPersonal: false
            )
            let image = TelegramMediaImage(
                imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: randomId),
                representations: [representation],
                immediateThumbnailData: nil,
                reference: nil,
                partialReference: nil,
                flags: []
            )
            return .image(image)
        }
    }

    private func sendLocalQuickReply(reply: JokerQuickReply) {
        guard canSendMessagesToChat(self.presentationInterfaceState) else {
            return
        }
        if self.presentationInterfaceState.interfaceState.editMessage != nil {
            return
        }

        let replySubject = self.presentationInterfaceState.interfaceState.replyMessageSubject
        let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages: [EnqueueMessage] = []

        if let media = reply.media, let mediaValue = self.makeLocalQuickReplyMedia(media) {
            var attributes: [MessageAttribute] = []
            if !text.isEmpty {
                let entities = generateTextEntities(text, enabledTypes: .all)
                if !entities.isEmpty {
                    attributes.append(TextEntitiesMessageAttribute(entities: entities))
                }
            }
            messages.append(.message(
                text: text,
                attributes: attributes,
                inlineStickers: [:],
                mediaReference: .standalone(media: mediaValue),
                threadId: self.chatLocation.threadId,
                replyToMessageId: replySubject?.subjectModel,
                replyToStoryId: nil,
                localGroupingKey: nil,
                correlationId: nil,
                bubbleUpEmojiOrStickersets: []
            ))
        } else if !text.isEmpty {
            var attributes: [MessageAttribute] = []
            let entities = generateTextEntities(text, enabledTypes: .all)
            if !entities.isEmpty {
                attributes.append(TextEntitiesMessageAttribute(entities: entities))
            }
            messages.append(.message(
                text: text,
                attributes: attributes,
                inlineStickers: [:],
                mediaReference: nil,
                threadId: self.chatLocation.threadId,
                replyToMessageId: replySubject?.subjectModel,
                replyToStoryId: nil,
                localGroupingKey: nil,
                correlationId: nil,
                bubbleUpEmojiOrStickersets: []
            ))
        }

        guard !messages.isEmpty else {
            return
        }

        self.chatDisplayNode.historyNode.justSentTextMessage = true
        self.chatDisplayNode.setupSendActionOnViewUpdate({ [weak self] in
            guard let self else {
                return
            }
            self.chatDisplayNode.collapseInput()
            self.chatDisplayNode.textInputPanelNode?.text = ""
            self.updateChatPresentationInterfaceState(animated: true, interactive: false, {
                $0.updatedInterfaceState { $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withUpdatedPostSuggestionState(nil) }
            })
        }, nil)

        self.sendMessages(messages, media: reply.media != nil, postpone: false)
    }
}

import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import Postbox
import SwiftSignalKit
import AccountContext
import UniversalMediaPlayer
import TelegramCallsUI
import TelegramPresentationData
import UndoUI
import TelegramUIPreferences
import TelegramStringFormatting

/// Joker: broadcast a message's audio file into the peer's voice chat directly from a chat.
///
/// A long-press menu item in groups and channels ("شغّل في المكالمة" / "Play in Voice Chat") downloads the audio
/// file (voice messages, mp3, ogg, … — anything FFmpeg can decode), joins (or creates) the peer's voice chat and
/// streams the decoded PCM into it as the account's voice, mixed with the microphone. Tap the item again to stop
/// the broadcast.
public final class ChatAudioBroadcast {
    public enum State: Equatable {
        case idle
        case fetching(messageId: MessageId)
        case broadcasting(messageId: MessageId)
    }

    public static let shared = ChatAudioBroadcast()

    private let statePromise = ValuePromise<State>(.idle, ignoreRepeated: true)
    public var stateSignal: Signal<State, NoError> {
        return self.statePromise.get()
    }
    public var state: State {
        return self.statePromise.with { $0 }
    }

    private var fetchDisposable: Disposable?
    private var prepareDisposable: Disposable?
    private var watcherDisposable: Disposable?

    private var currentCall: PresentationGroupCallImpl?
    private var pcmData: Data?
    private var pcmOffset = 0
    private var currentMessageId: MessageId?
    private let pcmLock = NSLock()
    private var injectionTimer: DispatchSourceTimer?
    private let injectionQueue = DispatchQueue(label: "chat.audioBroadcast.injection")

    private init() {
    }

    public func isBroadcasting(messageId: MessageId) -> Bool {
        if case let .broadcasting(id) = self.state, id == messageId {
            return true
        }
        return false
    }

    public func stop() {
        self.stopInjectionTimer()
        self.watcherDisposable?.dispose()
        self.watcherDisposable = nil
        self.fetchDisposable?.dispose()
        self.fetchDisposable = nil
        self.prepareDisposable?.dispose()
        self.prepareDisposable = nil
        self.pcmLock.lock()
        self.pcmData = nil
        self.pcmOffset = 0
        self.currentMessageId = nil
        self.currentCall = nil
        self.pcmLock.unlock()
        self.statePromise.set(.idle)
    }

    public func toggle(context: AccountContext, message: EngineRawMessage) {
        let peerId = message.id.peerId
        guard peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudChannel else {
            return
        }
        switch self.state {
        case .idle:
            break
        case let .fetching(messageId), let .broadcasting(messageId):
            if messageId == message.id {
                self.stop()
                return
            }
            self.stop()
        }
        self.begin(context: context, message: message)
    }

    private func begin(context: AccountContext, message: EngineRawMessage) {
        let file = message.media.compactMap { $0 as? TelegramMediaFile }.first(where: { file in
            let mime = file.mimeType.lowercased()
            return file.isVoice || file.isMusic || mime.hasPrefix("audio")
        })
        guard let file = file, let fileSize = file.size, fileSize > 0, fileSize < 128 * 1024 * 1024 else {
            self.presentToast(context: context, text: context.sharedContext.currentPresentationData.with { $0 }.strings.Chat_AudioBroadcast_NoAudio)
            return
        }
        self.statePromise.set(.fetching(messageId: message.id))
        self.pcmLock.lock()
        self.currentMessageId = message.id
        self.pcmLock.unlock()

        // Kick off the fetch first (it registers the download in the fetch manager), then wait for the file to
        // become fully local, then hand the local path to the decoder.
        let fetchDisposable = messageMediaFileInteractiveFetched(context: context, message: message, file: file, userInitiated: true)
        self.fetchDisposable?.dispose()
        self.fetchDisposable = fetchDisposable.start()

        let pipeline = messageMediaFileStatus(context: context, messageId: message.id, file: file)
        |> filter { status -> Bool in
            if case .Local = status {
                return true
            }
            return false
        }
        |> take(1)
        |> mapToSignal { _ -> Signal<MediaResourceData, NoError> in
            return context.account.postbox.mediaBox.resourceData(file.resource, pathExtension: nil, option: .complete(waitUntilFetchStatus: true))
        }
        self.prepareDisposable?.dispose()
        self.prepareDisposable = pipeline.start(next: { [weak self] resourceData in
            guard let self else {
                return
            }
            self.decodeAndBroadcast(context: context, message: message, file: file, path: resourceData.path)
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            self.presentToast(context: context, text: context.sharedContext.currentPresentationData.with { $0 }.strings.Chat_AudioBroadcast_Failed)
            self.stop()
        })
    }

    private func decodeAndBroadcast(context: AccountContext, message: EngineRawMessage, file: TelegramMediaFile, path: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                return
            }
            autoreleasepool {
                let pcm = ChatAudioBroadcast.decodeWholeFile(path: path)
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    guard let pcm = pcm else {
                        self.presentToast(context: context, text: context.sharedContext.currentPresentationData.with { $0 }.strings.Chat_AudioBroadcast_Failed)
                        self.stop()
                        return
                    }
                    self.joinAndInject(context: context, message: message, pcmData: pcm)
                }
            }
        }
    }

    private func joinAndInject(context: AccountContext, message: EngineRawMessage, pcmData: Data) {
        let peerId = message.id.peerId
        let activeCall = context.engine.calls.updatedCurrentPeerGroupCall(peerId: peerId)
        |> take(1)
        |> deliverOnMainQueue
        self.prepareDisposable?.dispose()
        self.prepareDisposable = activeCall.start(next: { [weak self] description in
            guard let self else {
                return
            }
            if let description = description {
                self.joinCall(context: context, message: message, peerId: peerId, description: description, pcmData: pcmData)
            } else {
                self.createCallAndJoin(context: context, message: message, peerId: peerId, pcmData: pcmData)
            }
        })
    }

    private func createCallAndJoin(context: AccountContext, message: EngineRawMessage, peerId: EnginePeer.Id, pcmData: Data) {
        self.prepareDisposable?.dispose()
        self.prepareDisposable = (context.engine.calls.createGroupCall(peerId: peerId, title: nil, scheduleDate: nil, isExternalStream: false)
        |> deliverOnMainQueue).start(next: { [weak self] info in
            guard let self else {
                return
            }
            let description = EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: "", scheduleTimestamp: nil, subscribedToScheduled: false, isStream: nil)
            self.joinCall(context: context, message: message, peerId: peerId, description: description, pcmData: pcmData)
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            self.presentToast(context: context, text: context.sharedContext.currentPresentationData.with { $0 }.strings.Chat_AudioBroadcast_NoPermission)
            self.stop()
        })
    }

    private func joinCall(context: AccountContext, message: EngineRawMessage, peerId: EnginePeer.Id, description: EngineGroupCallDescription, pcmData: Data) {
        context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { completion in
            completion(nil)
        }, activeCall: description)
        context.sharedContext.navigateToCurrentCall()
        self.startInjection(context: context, message: message, pcmData: pcmData)
    }

    private func startInjection(context: AccountContext, message: EngineRawMessage, pcmData: Data) {
        self.stopInjectionTimer()
        self.pcmLock.lock()
        self.pcmData = pcmData
        self.pcmOffset = 0
        self.pcmLock.unlock()
        self.statePromise.set(.broadcasting(messageId: message.id))

        if let callManager = context.sharedContext.callManager {
            self.watcherDisposable?.dispose()
            self.watcherDisposable = (callManager.currentGroupCallSignal
            |> deliverOnMainQueue).start(next: { [weak self] call in
                guard let self else {
                    return
                }
                switch call {
                case let .group(impl):
                    if let impl = impl as? PresentationGroupCallImpl {
                        if self.currentCall !== impl {
                            self.activateInjectionTimer(call: impl)
                        }
                    } else {
                        self.stop()
                    }
                case .conferenceSource, .none:
                    self.stop()
                }
            })
        } else {
            self.stop()
        }
    }

    private func activateInjectionTimer(call: PresentationGroupCallImpl) {
        self.stopInjectionTimer()
        self.currentCall = call

        let samplesPerChunk = 480 // 10 ms at 48 kHz, mono 16-bit
        let bytesPerChunk = samplesPerChunk * 2

        let timer = DispatchSource.makeTimerSource(queue: self.injectionQueue)
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            self.pcmLock.lock()
            defer {
                self.pcmLock.unlock()
            }
            guard let data = self.pcmData else {
                return
            }
            let offset = self.pcmOffset
            if offset >= data.count {
                if self.currentMessageId != nil {
                    DispatchQueue.main.async {
                        self.stop()
                    }
                }
                return
            }
            let end = min(offset + bytesPerChunk, data.count)
            let chunk = data.subdata(in: offset ..< end)
            self.pcmOffset = end
            let targetCall = self.currentCall
            DispatchQueue.main.async {
                targetCall?.addExternalAudioData(data: chunk)
            }
        }
        self.injectionTimer = timer
        timer.resume()
    }

    private func stopInjectionTimer() {
        self.injectionTimer?.cancel()
        self.injectionTimer = nil
    }

    private func presentToast(context: AccountContext, text: String) {
        DispatchQueue.main.async {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), action: { _ in
                return true
            })
            context.sharedContext.presentControllerInCurrent(controller, nil)
        }
    }

    private static func decodeWholeFile(path: String) -> Data? {
        guard let reader = FFMpegFileReader(source: .file(path), selectedStream: .mediaType(.audio), seek: nil, useHardwareAcceleration: false) else {
            return nil
        }
        var pcm = Data()
        var finished = false
        var starved = 0
        while !finished {
            switch reader.readFrame() {
            case let .frame(frame):
                if let data = ChatAudioBroadcast.pcmFrameData(frame) {
                    pcm.append(data)
                }
                starved = 0
            case .waitingForMoreData:
                starved += 1
                if starved > 50 {
                    finished = true
                } else {
                    Thread.sleep(forTimeInterval: 0.002)
                }
            case .endOfStream, .error:
                finished = true
            }
        }
        return pcm.isEmpty ? nil : pcm
    }

    private static func pcmFrameData(_ frame: MediaTrackFrame) -> Data? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(frame.sampleBuffer) else {
            return nil
        }
        guard let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }
        let asbd = asbdPointer.pointee
        if (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) == 0 {
            return nil
        }
        let channelCount = Int(asbd.mChannelsPerFrame)
        if channelCount == 0 || channelCount > 2 {
            return nil
        }
        let bytesPerSample = Int(asbd.mBitsPerChannel) / 8
        if bytesPerSample != 2 {
            return nil
        }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()
        var needed = 0
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            frame.sampleBuffer,
            bufferListSizeNeededOut: &needed,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, audioBufferList.mNumberBuffers > 0, let bufferData = audioBufferList.mBuffers.mData else {
            return nil
        }
        let byteCount = Int(audioBufferList.mBuffers.mDataByteSize)
        guard byteCount >= 2 * channelCount else {
            return nil
        }
        if channelCount == 1 {
            return Data(bytes: bufferData, count: byteCount)
        }

        let sampleCount = byteCount / 2
        let samples = bufferData.bindMemory(to: Int16.self, capacity: sampleCount)
        var mono = [UInt8]()
        mono.reserveCapacity(sampleCount)
        var i = 0
        while i + 1 < sampleCount {
            let left = Int32(samples[i])
            let right = Int32(samples[i + 1])
            var value = (left + right) / 2
            if value > Int32(Int16.max) {
                value = Int32(Int16.max)
            } else if value < Int32(Int16.min) {
                value = Int32(Int16.min)
            }
            let value16 = Int16(truncatingIfNeeded: value)
            mono.append(UInt8(truncatingIfNeeded: value16 & 0xff))
            mono.append(UInt8(truncatingIfNeeded: (value16 >> 8) & 0xff))
            i += 2
        }
        return Data(mono)
    }
}

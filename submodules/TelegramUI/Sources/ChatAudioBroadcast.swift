import Foundation
import UIKit
import AVFoundation
import AsyncDisplayKit
import CoreMedia
import CoreAudio
import TelegramCore
import SwiftSignalKit
import AccountContext
import UniversalMediaPlayer
import TelegramCallsUI
import TelegramPresentationData
import UndoUI
import TelegramUIPreferences
import TelegramStringFormatting
import TelegramVoip

/// Joker: broadcast a message's audio file into the peer's voice chat directly from a chat.
///
/// A long-press menu item in groups and channels ("Play in Voice Chat") downloads the audio
/// file (voice messages, mp3, ogg, anything FFmpeg can decode), joins (or creates) the peer's voice chat and
/// streams the decoded PCM into it as the account's voice, mixed with the microphone. Tap the item again to stop
/// the broadcast.
public final class ChatAudioBroadcast {
    public enum State: Equatable {
        case idle
        case fetching(messageId: EngineMessage.Id)
        case broadcasting(messageId: EngineMessage.Id)
    }

    public static let shared = ChatAudioBroadcast()

    private let statePromise = ValuePromise<State>(.idle, ignoreRepeated: true)
    private var currentState: State = .idle
    public var stateSignal: Signal<State, NoError> {
        return self.statePromise.get()
    }
    public var state: State {
        return self.currentState
    }

    private func setState(_ state: State) {
        self.currentState = state
        self.statePromise.set(state)
    }

    private var fetchDisposable: Disposable?
    private var prepareDisposable: Disposable?
    private var watcherDisposable: Disposable?
    private var callStateDisposable: Disposable?

    private var currentCall: PresentationGroupCallImpl?
    private var pcmData: Data?
    private var pcmOffset = 0
    private var currentMessageId: EngineMessage.Id?
    private var pendingVideoPath: String?
    private var videoEnabledCall: PresentationGroupCallImpl?
    private var videoGeneration: Int = 0
    private var joinGeneration: Int = 0
    private let pcmLock = NSLock()
    private var injectionTimer: DispatchSourceTimer?
    private let injectionQueue = DispatchQueue(label: "chat.audioBroadcast.injection")

    private init() {
    }

    public func isBroadcasting(messageId: EngineMessage.Id) -> Bool {
        if case let .broadcasting(id) = self.state, id == messageId {
            return true
        }
        return false
    }

    // Joker Mod strings are kept inline with Arabic/English values, like the rest of the Joker UI:
    // the base UI ships English, Arabic comes from the downloaded localization pack, and keys added
    // by the Joker Mod are unknown to those packs (they would fall back to English).
    public static func broadcastPlayTitle(sample: String) -> String {
        return jokerLocalize(sample: sample, arValue: "شغّل في المكالمة الصوتية", enValue: "Play in Voice Chat")
    }

    public static func broadcastStopTitle(sample: String) -> String {
        return jokerLocalize(sample: sample, arValue: "أوقف البث في المكالمة", enValue: "Stop Voice Chat Broadcast")
    }

    public static func broadcastNoAudioText(sample: String) -> String {
        return jokerLocalize(sample: sample, arValue: "لا يوجد ملف صوتي أو فيديو في هذه الرسالة", enValue: "There's no audio or video file in this message")
    }

    public static func broadcastNoPermissionText(sample: String) -> String {
        return jokerLocalize(sample: sample, arValue: "يلزم صلاحية إشراف لبدء مكالمة صوتية", enValue: "You need admin rights to start a voice chat")
    }

    public static func broadcastFailedText(sample: String) -> String {
        return jokerLocalize(sample: sample, arValue: "تعذر تشغيل الصوت في المكالمة", enValue: "Couldn't play the audio in the voice chat")
    }

    public func stop() {
        self.stopInjectionTimer()
        self.joinGeneration += 1
        self.videoGeneration += 1
        if let videoEnabledCall = self.videoEnabledCall {
            self.videoEnabledCall = nil
            videoEnabledCall.disableVideo()
        }
        self.pendingVideoPath = nil
        self.watcherDisposable?.dispose()
        self.watcherDisposable = nil
        self.callStateDisposable?.dispose()
        self.callStateDisposable = nil
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
        self.setState(.idle)
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
            return file.isVoice || file.isMusic || file.isVideo || mime.hasPrefix("audio") || mime.hasPrefix("video")
        })
        guard let file = file, let fileSize = file.size, fileSize > 0, fileSize < 128 * 1024 * 1024 else {
            self.presentToast(context: context, text: ChatAudioBroadcast.broadcastNoAudioText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
            return
        }
        self.setState(.fetching(messageId: message.id))
        self.pcmLock.lock()
        self.currentMessageId = message.id
        self.pcmLock.unlock()

        // Kick off the fetch first (it registers the download in the fetch manager), then wait for the file to
        // become fully local, then hand the local path to the decoder.
        let fetchDisposable = messageMediaFileInteractiveFetched(context: context, message: message, file: file, userInitiated: true)
        self.fetchDisposable?.dispose()
        self.fetchDisposable = fetchDisposable.start()

        let resource = EngineMediaResource(file.resource)
        let pipeline = context.engine.resources.status(resource: resource)
        |> filter { status -> Bool in
            if case .Local = status {
                return true
            }
            return false
        }
        |> take(1)
        |> mapToSignal { _ -> Signal<EngineMediaResource.ResourceData, NoError> in
            return context.engine.resources.data(resource: resource, waitUntilFetchStatus: true)
        }
        self.prepareDisposable?.dispose()
        // The pipeline cannot produce an error (NoError), so a completion handler is used to detect the case
        // where the download status never reaches .Local.
        var didReceiveData = false
        self.prepareDisposable = pipeline.start(next: { [weak self] resourceData in
            didReceiveData = true
            guard let self else {
                return
            }
            self.decodeAndBroadcast(context: context, message: message, file: file, path: resourceData.path)
        }, completed: { [weak self] in
            if didReceiveData {
                return
            }
            guard let self else {
                return
            }
            self.presentToast(context: context, text: ChatAudioBroadcast.broadcastFailedText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
            self.stop()
        })
    }

    private func decodeAndBroadcast(context: AccountContext, message: EngineRawMessage, file: TelegramMediaFile, path: String) {
        let fileMime = file.mimeType.lowercased()
        self.pendingVideoPath = (file.isVideo || fileMime.hasPrefix("video")) ? path : nil
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
                        self.presentToast(context: context, text: ChatAudioBroadcast.broadcastFailedText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
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
        // Already inside the voice chat for this peer: injecting the external audio is enough.
        // Rejoining would tear the call down and reconnect it.
        if let callManager = context.sharedContext.callManager {
            self.prepareDisposable?.dispose()
            self.prepareDisposable = (callManager.currentGroupCallSignal |> take(1) |> deliverOnMainQueue).start(next: { [weak self] call in
                guard let self else {
                    return
                }
                switch call {
                case let .group(groupCall):
                    if let impl = groupCall as? PresentationGroupCallImpl, impl.peerId == peerId {
                        self.startInjection(context: context, message: message, pcmData: pcmData)
                        return
                    }
                default:
                    break
                }
                self.fetchGroupCallDescriptionAndJoin(context: context, message: message, peerId: peerId, pcmData: pcmData)
            })
            return
        }
        self.fetchGroupCallDescriptionAndJoin(context: context, message: message, peerId: peerId, pcmData: pcmData)
    }

    private func fetchGroupCallDescriptionAndJoin(context: AccountContext, message: EngineRawMessage, peerId: EnginePeer.Id, pcmData: Data) {
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
            let description = EngineGroupCallDescription(id: info.id, accessHash: info.accessHash, title: info.title, scheduleTimestamp: nil, subscribedToScheduled: false, isStream: info.isStream)
            self.joinCall(context: context, message: message, peerId: peerId, description: description, pcmData: pcmData)
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            self.presentToast(context: context, text: ChatAudioBroadcast.broadcastNoPermissionText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
            self.stop()
        })
    }

    private func joinCall(context: AccountContext, message: EngineRawMessage, peerId: EnginePeer.Id, description: EngineGroupCallDescription, pcmData: Data) {
        context.joinGroupCall(peerId: peerId, invite: nil, requestJoinAsPeerId: { completion in
            completion(nil)
        }, activeCall: description)
        self.startInjection(context: context, message: message, pcmData: pcmData)
    }

    private func startInjection(context: AccountContext, message: EngineRawMessage, pcmData: Data) {
        self.stopInjectionTimer()
        self.joinGeneration += 1
        let generation = self.joinGeneration
        self.pcmLock.lock()
        self.pcmData = pcmData
        self.pcmOffset = 0
        self.pcmLock.unlock()
        self.setState(.broadcasting(messageId: message.id))

        if let callManager = context.sharedContext.callManager {
            self.watcherDisposable?.dispose()
            self.watcherDisposable = (callManager.currentGroupCallSignal
            |> deliverOnMainQueue).start(next: { [weak self] call in
                guard let self else {
                    return
                }
                switch call {
                case let .group(impl):
                    if let impl = impl as? PresentationGroupCallImpl, impl.peerId == message.id.peerId {
                        if self.currentCall !== impl {
                            self.activateInjectionTimer(call: impl, context: context)
                        }
                    }
                case .conferenceSource, .none:
                    // The call may still be connecting (or another call is active while the
                    // switch dialog is shown); keep waiting for the target call.
                    break
                }
            })
        } else {
            self.stop()
        }

        // If the call never becomes available (for example the user cancelled the "end current
        // call" dialog or the join failed), stop instead of staying in the broadcasting state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) { [weak self] in
            guard let self else {
                return
            }
            guard self.joinGeneration == generation else {
                return
            }
            guard case .broadcasting = self.state, self.currentCall == nil else {
                return
            }
            self.presentToast(context: context, text: ChatAudioBroadcast.broadcastFailedText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
            self.stop()
        }
    }

    private func activateInjectionTimer(call: PresentationGroupCallImpl, context: AccountContext) {
        self.stopInjectionTimer()
        self.currentCall = call
        context.sharedContext.navigateToCurrentCall()

        // Wait until the call is actually connected: the external audio is buffered by the call engine for at most
        // a couple of seconds, so starting earlier would lose the beginning of the track.
        self.callStateDisposable?.dispose()
        self.callStateDisposable = (call.state
        |> filter { state -> Bool in
            return state.networkState == .connected
        }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            guard self.currentCall === call else {
                return
            }
            self.startBroadcast()
            if let videoPath = self.pendingVideoPath {
                self.startVideoInjection(context: context, call: call, path: videoPath)
            }
        })
    }

    private func startBroadcast() {
        // The samples injected into the call are only sent to the other participants (they are mixed into the outgoing/microphone stream).
        // The sender hears the same track locally by mixing it into the render path of the call engine.
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

    // Joker: stream a video file into the call as the local video. Others see the video, its audio
    // is injected separately by the audio path above. Uses the external sample buffer provider.
    //
    // Video frames are read with AVAssetReader (hardware decoding — the same pipeline used by the
    // broadcast upload extension), which supports every codec/container iOS can play (HEVC, H.264,
    // AV1, MP4/MOV...). Containers AVFoundation cannot read (mkv, webm, avi) fall back to the
    // FFMpeg software decoder. Any total failure shows a toast instead of leaving a spinner forever.
    private func startVideoInjection(context: AccountContext, call: PresentationGroupCallImpl, path: String) {
        self.videoGeneration += 1
        let generation = self.videoGeneration
        guard self.videoEnabledCall == nil || self.videoEnabledCall === call else {
            // A video is already being broadcast by this feature; do not stack another one.
            return
        }

        let videoCapturer = OngoingCallVideoCapturer(isCustom: true)
        self.videoEnabledCall = call
        call.requestVideo(capturer: videoCapturer)

        guard let prepared = self.prepareAVFoundationVideoInjection(path: path, generation: generation, videoCapturer: videoCapturer) else {
            print("ChatAudioBroadcast: AVAssetReader could not read \(path); falling back to FFMpeg")
            self.startFFmpegVideoInjection(context: context, call: call, path: path, generation: generation, videoCapturer: videoCapturer)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            prepared()
        }
    }

    private func prepareAVFoundationVideoInjection(path: String, generation: Int, videoCapturer: OngoingCallVideoCapturer) -> (() -> Void)? {
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        guard let videoTrack = asset.tracks(withMediaType: .video).first, videoTrack.isEnabled else {
            return nil
        }
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        trackOutput.alwaysCopiesSampleData = false
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            return nil
        }
        guard assetReader.canAdd(trackOutput) else {
            return nil
        }
        assetReader.add(trackOutput)
        if !assetReader.startReading() {
            return nil
        }

        // A paused transform does not describe the upright player: rotate it to the transform's angle.
        let transform = videoTrack.preferredTransform
        let angle = atan2(transform.b, transform.a)
        let rotation: CGImagePropertyOrientation
        switch angle {
        case 0:
            rotation = .up
        case .pi / 2:
            rotation = .left
        case -.pi / 2:
            rotation = .right
        case .pi, -.pi:
            rotation = .down
        default:
            rotation = .up
        }

        let nominalFps = Double(videoTrack.nominalFrameRate)
        let fps = max(1.0, min(60.0, nominalFps.isFinite && nominalFps > 0 ? floor(nominalFps) : 30.0))
        let defaultFrameSeconds = 1.0 / fps
        return { [weak self] in
            guard let self else {
                return
            }
            // Give the audio injection a small head start before frames appear.
            var nextTime = CACurrentMediaTime() + 0.25
            var framesInjected = 0
            while self.videoGeneration == generation {
                if let sampleBuffer = trackOutput.copyNextSampleBuffer() {
                    let duration = CMSampleBufferGetDuration(sampleBuffer)
                    let frameSeconds = duration.isValid && !duration.isIndefinite && !duration.isPositiveInfinity && !duration.isNegativeInfinity && duration.seconds.isFinite && duration.seconds > 0 ? duration.seconds : defaultFrameSeconds
                    let wait = nextTime - CACurrentMediaTime()
                    if wait > 0.001 {
                        Thread.sleep(forTimeInterval: min(wait, 0.5))
                    }
                    nextTime = max(nextTime + frameSeconds, CACurrentMediaTime())
                    videoCapturer.injectSampleBuffer(sampleBuffer, rotation: rotation, completion: {})
                    framesInjected += 1
                } else {
                    print("ChatAudioBroadcast: ended playing video \(path), frames injected: \(framesInjected), reader status: \(assetReader.status.rawValue)")
                    DispatchQueue.main.async { [weak self] in
                        self?.teardownVideo()
                    }
                    return
                }
            }
            if assetReader.status != .completed && assetReader.status != .cancelled {
                assetReader.cancelReading()
            }
        }
    }

    // FFMpeg software fallback for containers AVFoundation cannot read (mkv, webm, avi).
    // Audio of the same file is decoded separately at broadcast start, so this is video-only.
    private func startFFmpegVideoInjection(context: AccountContext, call: PresentationGroupCallImpl, path: String, generation: Int, videoCapturer: OngoingCallVideoCapturer) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else {
                return
            }
            guard self.videoGeneration == generation else {
                return
            }
            guard let reader = FFMpegFileReader(source: .file(path), useHardwareAcceleration: false, selectedStream: .mediaType(.video), seek: nil, maxReadablePts: nil) else {
                DispatchQueue.main.async { [weak self] in
                    self?.teardownVideo()
                    self?.presentToast(context: context, text: ChatAudioBroadcast.broadcastFailedText(sample: context.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back))
                }
                return
            }

            let fps = Double(max(1, min(60, reader.frameRate())))
            let defaultFrameSeconds = 1.0 / fps
            // Give the audio injection a small head start before frames appear.
            var nextTime = CACurrentMediaTime() + 0.25
            while self.videoGeneration == generation {
                switch reader.readFrame() {
                case let .frame(frame):
                    guard frame.type == .video else {
                        continue
                    }
                    let frameSeconds = frame.duration.seconds.isFinite && frame.duration.seconds > 0 ? frame.duration.seconds : defaultFrameSeconds
                    let wait = nextTime - CACurrentMediaTime()
                    if wait > 0.001 {
                        Thread.sleep(forTimeInterval: min(wait, 0.5))
                    }
                    nextTime = max(nextTime + frameSeconds, CACurrentMediaTime())
                    let angle = (frame.rotationAngle.rounded()).truncatingRemainder(dividingBy: 360.0)
                    let rotation: CGImagePropertyOrientation
                    switch angle {
                    case 90, -270:
                        rotation = .left
                    case 180, -180:
                        rotation = .down
                    case 270, -90:
                        rotation = .right
                    default:
                        rotation = .up
                    }
                    videoCapturer.injectSampleBuffer(frame.sampleBuffer, rotation: rotation, completion: {})
                case .waitingForMoreData:
                    Thread.sleep(forTimeInterval: 0.002)
                case .endOfStream, .error:
                    DispatchQueue.main.async { [weak self] in
                        self?.teardownVideo()
                    }
                    return
                }
            }
        }
    }

    private func teardownVideo() {
        // Called when the file reaches its end: turn off only the video this feature enabled.
        if let call = self.videoEnabledCall {
            self.videoEnabledCall = nil
            call.disableVideo()
        }
        self.videoGeneration += 1
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
            context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
        }
    }

    private static func decodeWholeFile(path: String) -> Data? {
        guard let reader = FFMpegFileReader(source: .file(path), useHardwareAcceleration: false, selectedStream: .mediaType(.audio), seek: nil, maxReadablePts: nil) else {
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
                // Cap the decoded size (~35 minutes of 48 kHz mono 16-bit audio) so that a very long file
                // cannot exhaust memory.
                if pcm.count >= 200 * 1024 * 1024 {
                    finished = true
                }
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

import Foundation
import AudioToolbox
import AVFoundation
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import UndoUI

// Joker Mod: local call recording for private calls, group chats and channel voice chats.
// Tap the record button during a call to record both sides at 48 kHz into temporary WAV files.
// When the recording is stopped the two tracks are merged and encoded into a high quality
// M4A/AAC file which is automatically sent to the user's Saved Messages.
public final class CallRecording {
    public typealias AudioRecordingHandler = (UnsafePointer<Int16>, Int, UInt32, UInt32, Bool) -> Void

    public static let shared = CallRecording()

    private let statePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var stateSignal: Signal<Bool, NoError> {
        return self.statePromise.get()
    }

    private var currentState: Bool = false
    private var currentPeerName: String = ""

    public var isRecording: Bool {
        return self.currentState
    }

    private let lock = NSLock()
    private var micFile: FileHandle?
    private var otherFile: FileHandle?
    private var recordingDirectory: URL?
    private var micByteCount: UInt64 = 0
    private var otherByteCount: UInt64 = 0
    private var startedAt: Date?
    private var durationSeconds: Int32 = 0
    private var updateTimer: DispatchSourceTimer?

    public var duration: Int32 {
        return self.durationSeconds
    }

    private init() {
    }

    public func toggle(accountContext: AccountContext, call: PresentationCall, peerName: String) {
        if self.currentState {
            self.stop(accountContext: accountContext, clearHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        } else {
            self.start(accountContext: accountContext, peerName: peerName, setHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        }
    }

    public func toggle(accountContext: AccountContext, call: PresentationGroupCall, peerName: String) {
        if self.currentState {
            self.stop(accountContext: accountContext, clearHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        } else {
            self.start(accountContext: accountContext, peerName: peerName, setHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        }
    }

    private func start(accountContext: AccountContext, peerName: String, setHandler: @escaping (AudioRecordingHandler?) -> Void) {
        guard !self.currentState else {
            return
        }
        self.currentPeerName = peerName
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("joker-call-recording-\(UUID().uuidString)", isDirectory: true)
        var micFile: FileHandle?
        var otherFile: FileHandle?
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let micURL = directory.appendingPathComponent("mic.wav")
            let otherURL = directory.appendingPathComponent("other.wav")
            FileManager.default.createFile(atPath: micURL.path, contents: nil)
            FileManager.default.createFile(atPath: otherURL.path, contents: nil)
            micFile = try FileHandle(forWritingTo: micURL)
            otherFile = try FileHandle(forWritingTo: otherURL)
            try micFile?.write(contentsOf: Self.makeWavHeader(channels: 1, sampleRate: 48000, dataSize: 0))
            try otherFile?.write(contentsOf: Self.makeWavHeader(channels: 1, sampleRate: 48000, dataSize: 0))
        } catch {
            return
        }
        self.lock.lock()
        self.micFile = micFile
        self.otherFile = otherFile
        self.recordingDirectory = directory
        self.micByteCount = 0
        self.otherByteCount = 0
        self.startedAt = Date()
        self.durationSeconds = 0
        self.lock.unlock()
        setHandler { [weak self] samples, frameCount, channels, sampleRate, isCapture in
            self?.appendFrames(samples: samples, frameCount: frameCount, channelCount: channels, sampleRate: sampleRate, isCapture: isCapture)
        }
        self.currentState = true
        self.statePromise.set(true)
        self.startUpdateTimer()
        let sample = accountContext.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back
        let text = jokerLocalize(sample: sample, arValue: "بدأ تسجيل المكالمة", enValue: "Call recording started")
        self.presentToast(context: accountContext, text: text)
    }

    private func stop(accountContext: AccountContext, clearHandler: @escaping (AudioRecordingHandler?) -> Void) {
        guard self.currentState else {
            return
        }
        clearHandler(nil)
        self.currentState = false
        self.statePromise.set(false)
        self.stopUpdateTimer()

        self.lock.lock()
        let directory = self.recordingDirectory
        let micFile = self.micFile
        let otherFile = self.otherFile
        let micBytes = self.micByteCount
        let otherBytes = self.otherByteCount
        self.micFile = nil
        self.otherFile = nil
        self.recordingDirectory = nil
        self.lock.unlock()

        guard let directory else {
            return
        }
        let micURL = directory.appendingPathComponent("mic.wav")
        let otherURL = directory.appendingPathComponent("other.wav")
        let peerName = self.currentPeerName
        // Finalize the WAV headers with the real sizes.
        let tracks: [(URL, FileHandle?, UInt64)] = [(micURL, micFile, micBytes), (otherURL, otherFile, otherBytes)]
        for (_, file, bytes) in tracks {
            if bytes > 0 {
                file?.seek(toFileOffset: 0)
                try? file?.write(contentsOf: Self.makeWavHeader(channels: 1, sampleRate: 48000, dataSize: UInt32(truncatingIfNeeded: bytes)))
            }
            try? file?.close()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                try? FileManager.default.removeItem(at: directory)
            }
            let micData = (try? Data(contentsOf: micURL, options: .mappedIfSafe)) ?? Data()
            let otherData = (try? Data(contentsOf: otherURL, options: .mappedIfSafe)) ?? Data()
            let micKB = micData.count / 1024
            let otherKB = otherData.count / 1024
            let merged = Self.mergePCMData(mic: micData, other: otherData)
            let duration = Int32(Double(merged.count / 2) / 48000.0)

            var sentSummary: [String] = []
            if let m4aURL = Self.encodeToM4A(pcm: merged) {
                Self.sendRecording(context: accountContext, fileURL: m4aURL, duration: duration, fileName: Self.recordingFileName(extension: "m4a", peerName: peerName), mimeType: "audio/x-m4a")
                sentSummary.append("M4A")
            }
            DispatchQueue.main.async {
                let sample = accountContext.sharedContext.currentPresentationData.with { $0 }.strings.Common_Back
                let text: String
                if sentSummary.isEmpty {
                    text = jokerLocalize(sample: sample, arValue: "تعذر إنشاء ملف التسجيل", enValue: "Failed to create the recording file")
                } else {
                    text = jokerLocalize(sample: sample, arValue: "تم التسجيل — مايكروفون \(micKB)KB · البقية \(otherKB)KB (أُرسل \(sentSummary.joined(separator: " و")))", enValue: "Recorded — mic \(micKB)KB · others \(otherKB)KB (sent \(sentSummary.joined(separator: " and ")))")
                }
                self.presentToast(context: accountContext, text: text)
            }
        }
    }

    private func appendFrames(samples: UnsafePointer<Int16>, frameCount: Int, channelCount: UInt32, sampleRate: UInt32, isCapture: Bool) {
        let data: Data
        if channelCount == 2 {
            var mono = Data(capacity: frameCount * 2)
            for i in 0 ..< frameCount {
                let left = Int32(samples[i * 2])
                let right = Int32(samples[i * 2 + 1])
                var value = (left + right) / 2
                value = max(-32768, min(32767, value))
                let sample16 = Int16(truncatingIfNeeded: value)
                var sample16le = sample16.littleEndian
                withUnsafeBytes(of: &sample16le) { mono.append(contentsOf: $0) }
            }
            data = mono
        } else {
            data = Data(bytes: samples, count: frameCount * 2 * Int(channelCount))
        }
        self.lock.lock()
        if isCapture {
            try? self.micFile?.write(contentsOf: data)
            self.micByteCount &+= UInt64(data.count)
        } else {
            try? self.otherFile?.write(contentsOf: data)
            self.otherByteCount &+= UInt64(data.count)
        }
        self.lock.unlock()
        self.durationSeconds = Int32(Date().timeIntervalSince(self.startedAt ?? Date()))
    }

    private func startUpdateTimer() {
        self.stopUpdateTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self, let startedAt = self.startedAt else {
                return
            }
            self.durationSeconds = Int32(Date().timeIntervalSince(startedAt))
        }
        self.updateTimer = timer
        timer.resume()
    }

    private func stopUpdateTimer() {
        self.updateTimer?.cancel()
        self.updateTimer = nil
    }

    private static func makeWavHeader(channels: UInt32, sampleRate: UInt32, dataSize: UInt32) -> Data {
        var header = Data()
        func appendUInt32(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { header.append(contentsOf: $0) }
        }
        func appendUInt16(_ value: UInt16) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { header.append(contentsOf: $0) }
        }
        header.append(contentsOf: Array("RIFF".utf8))
        appendUInt32(36 &+ dataSize)
        header.append(contentsOf: Array("WAVE".utf8))
        header.append(contentsOf: Array("fmt ".utf8))
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(UInt16(channels))
        appendUInt32(sampleRate)
        appendUInt32(sampleRate &* UInt32(channels) &* 2)
        appendUInt16(UInt16(channels) &* 2)
        appendUInt16(16)
        header.append(contentsOf: Array("data".utf8))
        appendUInt32(dataSize)
        return header
    }

    private static func mergePCMData(mic: Data, other: Data) -> Data {
        let micPayload = mic.count > 44 ? mic.subdata(in: 44 ..< mic.count) : Data()
        let otherPayload = other.count > 44 ? other.subdata(in: 44 ..< other.count) : Data()
        let micBytes = [UInt8](micPayload)
        let otherBytes = [UInt8](otherPayload)
        let micSampleCount = micBytes.count / 2
        let otherSampleCount = otherBytes.count / 2
        let count = max(micSampleCount, otherSampleCount)

        func sampleAt(_ bytes: [UInt8], _ byteIndex: Int) -> Int32 {
            let lo = UInt16(bytes[byteIndex])
            let hi = UInt16(bytes[byteIndex + 1])
            return Int32(Int16(bitPattern: lo | (hi << 8)))
        }

        var result = Data(capacity: count * 2)
        for i in 0 ..< count {
            var sample: Int32 = 0
            if i < micSampleCount {
                sample += sampleAt(micBytes, i * 2)
            }
            if i < otherSampleCount {
                sample += sampleAt(otherBytes, i * 2)
            }
            sample = max(-32768, min(32767, sample))
            let value16 = Int16(truncatingIfNeeded: sample)
            result.append(UInt8(truncatingIfNeeded: value16))
            result.append(UInt8(truncatingIfNeeded: value16 >> 8))
        }
        return result
    }

    private static func encodeToM4A(pcm: Data, sampleRate: Float64 = 48000.0) -> URL? {
        guard !pcm.isEmpty else {
            return nil
        }
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("JokerCallRecording-\(UUID().uuidString).m4a")

        // File format: AAC in an M4A container.
        var fileFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 0,
            mReserved: 0)
        // Format of the PCM data we feed to the encoder.
        var inputFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0)

        var extAudioFile: ExtAudioFileRef?
        var status = ExtAudioFileCreateWithURL(outURL as CFURL, kAudioFileM4AType, &fileFormat, nil, 0, &extAudioFile)
        guard status == noErr, let fileID = extAudioFile else {
            return nil
        }
        // Tell the encoder that the buffer we feed it is linear PCM.
        // Without this property the data is not encoded correctly.
        status = ExtAudioFileSetProperty(fileID, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &inputFormat)
        guard status == noErr else {
            ExtAudioFileDispose(fileID)
            return nil
        }

        let frameCount = pcm.count / 2
        let bytes = [UInt8](pcm)
        var wroteAny = false
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else {
                return
            }
            var offset = 0
            while offset < frameCount {
                let count = min(4096, frameCount - offset)
                var audioBuffer = AudioBuffer()
                audioBuffer.mNumberChannels = 1
                audioBuffer.mDataByteSize = UInt32(count * 2)
                audioBuffer.mData = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(base.advanced(by: offset * 2)))
                var audioBufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: audioBuffer)
                let writeStatus = ExtAudioFileWrite(fileID, UInt32(count), &audioBufferList)
                if writeStatus == noErr {
                    wroteAny = true
                }
                offset += count
            }
        }

        ExtAudioFileDispose(fileID)
        return wroteAny ? outURL : nil
    }

    private static func sendRecording(context: AccountContext, fileURL: URL, duration: Int32, fileName: String, mimeType: String) {
        let attributes: [TelegramMediaFileAttribute] = [
            .FileName(fileName: fileName),
            .Audio(isVoice: false, duration: Int(duration), title: nil, performer: nil, waveform: nil)
        ]
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size]) as? Int64
        let id = Int64.random(in: Int64.min ... Int64.max)
        let file = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: fileURL.path, randomId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: fileSize, attributes: attributes, alternativeRepresentations: [])
        let message = EnqueueMessage.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        let _ = enqueueMessages(account: context.account, peerId: context.account.peerId, messages: [message]).start()
    }

    private static func recordingFileName(extension ext: String, peerName: String) -> String {
        let sanitized = peerName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = String(sanitized.prefix(48))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let date = formatter.string(from: Date())
        if trimmed.isEmpty {
            return "تسجيل \(date).\(ext)"
        } else {
            return "تسجيل \(trimmed) \(date).\(ext)"
        }
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
}

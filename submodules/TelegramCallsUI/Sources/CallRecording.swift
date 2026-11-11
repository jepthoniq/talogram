import Foundation
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

    public func toggle(accountContext: AccountContext, call: PresentationCall) {
        if self.currentState {
            self.stop(accountContext: accountContext, clearHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        } else {
            self.start(accountContext: accountContext, setHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        }
    }

    public func toggle(accountContext: AccountContext, call: PresentationGroupCall) {
        if self.currentState {
            self.stop(accountContext: accountContext, clearHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        } else {
            self.start(accountContext: accountContext, setHandler: { handler in call.setJokerAudioRecordingHandler(handler) })
        }
    }

    private func start(accountContext: AccountContext, setHandler: @escaping (AudioRecordingHandler?) -> Void) {
        guard !self.currentState else {
            return
        }
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
                Self.sendRecording(context: accountContext, fileURL: m4aURL, duration: duration, fileName: Self.recordingFileName(extension: "m4a"), mimeType: "audio/x-m4a")
                sentSummary.append("M4A")
            }
            if let wavURL = Self.writeMergedWAV(pcm: merged) {
                Self.sendRecording(context: accountContext, fileURL: wavURL, duration: duration, fileName: Self.recordingFileName(extension: "wav"), mimeType: "audio/x-wav")
                sentSummary.append("WAV")
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
        return micPayload.withUnsafeBytes { micRaw in
            return otherPayload.withUnsafeBytes { otherRaw in
                let micSamples = micRaw.bindMemory(to: Int16.self)
                let otherSamples = otherRaw.bindMemory(to: Int16.self)
                let count = max(micSamples.count, otherSamples.count)
                var result = Data(capacity: count * 2)
                for i in 0 ..< count {
                    var sample: Int32 = 0
                    if i < micSamples.count {
                        sample += Int32(micSamples[i])
                    }
                    if i < otherSamples.count {
                        sample += Int32(otherSamples[i])
                    }
                    sample = max(-32768, min(32767, sample))
                    let value16 = Int16(truncatingIfNeeded: sample)
                    var value = value16.littleEndian
                    withUnsafeBytes(of: &value) { result.append(contentsOf: $0) }
                }
                return result
            }
        }
    }

    private static func encodeToM4A(pcm: Data, sampleRate: Double = 48000.0) -> URL? {
        guard !pcm.isEmpty else {
            return nil
        }
        var floats = [Float]()
        floats.reserveCapacity(pcm.count / 2)
        pcm.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for sample in samples {
                floats.append(Float(sample) / 32768.0)
            }
        }

        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let outURL = FileManager.default.temporaryDirectory.appendingPathComponent("JokerCallRecording-\(UUID().uuidString).m4a")
        do {
            let outFile = try AVAudioFile(forWriting: outURL, settings: outputSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let converter = AVAudioConverter(from: inputFormat, to: outFile.processingFormat) else {
                return nil
            }
            let chunkFrames = 4096
            var position = 0
            while position < floats.count {
                let frameCount = AVAudioFrameCount(min(chunkFrames, floats.count - position))
                guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(chunkFrames)) else {
                    return nil
                }
                inBuffer.frameLength = frameCount
                inBuffer.floatChannelData![0].update(from: &floats[position], count: Int(frameCount))
                guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: AVAudioFrameCount(chunkFrames + 32)) else {
                    return nil
                }
                var error: NSError?
                var supplied = false
                let status = converter.convert(to: outBuffer, error: &error) { inPacketCount, outStatus in
                    if supplied {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    supplied = true
                    outStatus.pointee = .haveData
                    return inBuffer
                }
                if status == .error || error != nil {
                    return nil
                }
                try outFile.write(from: outBuffer)
                position += Int(frameCount)
            }
            // Flush the encoder.
            let emptyIn = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 1)!
            emptyIn.frameLength = 0
            if let outBuffer = AVAudioPCMBuffer(pcmFormat: outFile.processingFormat, frameCapacity: 256) {
                var error: NSError?
                var supplied = false
                let status = converter.convert(to: outBuffer, error: &error) { inPacketCount, outStatus in
                    if supplied {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    supplied = true
                    outStatus.pointee = .endOfStream
                    return emptyIn
                }
                if status != .error, outBuffer.frameLength > 0 {
                    try? outFile.write(from: outBuffer)
                }
            }
            return outURL
        } catch {
            return nil
        }
    }

    private static func writeMergedWAV(pcm: Data) -> URL? {
        guard !pcm.isEmpty else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("JokerCallRecording-\(UUID().uuidString).wav")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            return nil
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.write(contentsOf: Self.makeWavHeader(channels: 1, sampleRate: 48000, dataSize: UInt32(clamping: pcm.count)))
            try handle.write(contentsOf: pcm)
            try handle.close()
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
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

    private static func recordingFileName(extension ext: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Call Recording \(formatter.string(from: Date())).\(ext)"
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

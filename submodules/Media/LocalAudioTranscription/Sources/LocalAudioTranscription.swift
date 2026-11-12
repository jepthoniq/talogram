import Foundation
import AVFoundation
import Speech
import SwiftSignalKit
import ConvertOpusToAAC

private var sharedRecognizers: [String: SFSpeechRecognizer] = [:]

private struct TranscriptionResult {
    var text: String
    var confidence: Float
    var isFinal: Bool
}

private struct PreparedAudioChunk {
    let path: String
    let duration: Double
}

private func parseLanguageRegion(_ identifier: String) -> (language: String, region: String?) {
    let normalized = identifier.replacingOccurrences(of: "_", with: "-")
    let parts = normalized.split(separator: "-").map(String.init)
    let language = parts.first?.lowercased() ?? normalized.lowercased()
    var region: String? = nil
    if parts.count >= 2 {
        region = parts[parts.count - 1].uppercased()
    }
    return (language, region)
}

private func resolveSupportedLocale(_ preferred: String) -> Locale? {
    let supported = SFSpeechRecognizer.supportedLocales()
    let (language, region) = parseLanguageRegion(preferred)

    func supportedFor(languageCode: String) -> [Locale] {
        return supported.filter { locale in
            let parts = parseLanguageRegion(locale.identifier)
            return parts.language == languageCode
        }.map { $0 }
    }

    let languageMatches = supportedFor(languageCode: language)
    if let region = region {
        if let exact = languageMatches.first(where: { parseLanguageRegion($0.identifier).region == region }) {
            return exact
        }
    }
    if let deviceRegion = parseLanguageRegion(Locale.current.identifier).region {
        if let exact = languageMatches.first(where: { parseLanguageRegion($0.identifier).region == deviceRegion }) {
            return exact
        }
    }
    if let byLanguage = languageMatches.first {
        return byLanguage
    }
    let deviceLanguage = parseLanguageRegion(Locale.current.identifier).language
    let deviceMatches = supportedFor(languageCode: deviceLanguage)
    if let deviceRegion = parseLanguageRegion(Locale.current.identifier).region {
        if let exact = deviceMatches.first(where: { parseLanguageRegion($0.identifier).region == deviceRegion }) {
            return exact
        }
    }
    if let byDevice = deviceMatches.first {
        return byDevice
    }
    return supportedFor(languageCode: "en").first ?? supported.first
}

private func recognizerForLocale(_ locale: Locale) -> SFSpeechRecognizer? {
    let key = locale.identifier
    if let existing = sharedRecognizers[key] {
        return existing
    }
    guard let recognizer = SFSpeechRecognizer(locale: locale) else {
        return nil
    }
    recognizer.defaultTaskHint = .dictation
    sharedRecognizers[key] = recognizer
    return recognizer
}

private func onDeviceRecognitionSupported(locale: String) -> Bool {
    guard let resolvedLocale = resolveSupportedLocale(locale), let recognizer = recognizerForLocale(resolvedLocale) else {
        return false
    }
    return recognizer.supportsOnDeviceRecognition
}

private func speechAuthorizationSignal() -> Signal<Bool, NoError> {
    let signal = Signal<Bool, NoError> { subscriber in
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            subscriber.putNext(true)
            subscriber.putCompletion()
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { newStatus in
                Queue.mainQueue().async {
                    print("LocalTranscription: authorization result \(newStatus.rawValue)")
                    subscriber.putNext(newStatus == .authorized)
                    subscriber.putCompletion()
                }
            }
        default:
            print("LocalTranscription: authorization status \(status.rawValue)")
            subscriber.putNext(false)
            subscriber.putCompletion()
        }
        return EmptyDisposable
    }
    return signal
    |> runOn(.mainQueue())
    |> timeout(30.0, queue: .mainQueue(), alternate: .single(false))
}

private func recognizeFile(path: String, locale: String, preferOnDevice: Bool, timeoutSeconds: Double) -> Signal<TranscriptionResult?, NoError> {
    let signal = Signal<TranscriptionResult?, NoError> { subscriber in
        guard let resolvedLocale = resolveSupportedLocale(locale) else {
            print("LocalTranscription: no supported locale for \(locale)")
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        guard let recognizer = recognizerForLocale(resolvedLocale) else {
            print("LocalTranscription: could not create a recognizer for \(resolvedLocale.identifier)")
            subscriber.putNext(nil)
            subscriber.putCompletion()
            return EmptyDisposable
        }

        let useOnDevice = preferOnDevice && recognizer.supportsOnDeviceRecognition
        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: path))
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = true
        }
        request.requiresOnDeviceRecognition = useOnDevice
        request.shouldReportPartialResults = false

        print("LocalTranscription: recognizing locale=\(resolvedLocale.identifier) onDevice=\(useOnDevice) path=\(path)")

        let task = recognizer.recognitionTask(with: request, resultHandler: { result, error in
            Queue.mainQueue().async {
                if let result = result {
                    let segments = result.bestTranscription.segments
                    var confidence: Float = 0.0
                    for segment in segments {
                        confidence += segment.confidence
                    }
                    if !segments.isEmpty {
                        confidence /= Float(segments.count)
                    }
                    let text = result.bestTranscription.formattedString
                    print("LocalTranscription: result locale=\(resolvedLocale.identifier) onDevice=\(useOnDevice) final=\(result.isFinal) characters=\(text.count)")
                    subscriber.putNext(TranscriptionResult(text: text, confidence: confidence, isFinal: result.isFinal))
                    subscriber.putCompletion()
                } else {
                    print("LocalTranscription: recognition error locale=\(resolvedLocale.identifier) onDevice=\(useOnDevice) error=\(String(describing: error))")
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            }
        })
        return ActionDisposable {
            task.cancel()
        }
    }
    return signal
    |> runOn(.mainQueue())
    |> timeout(timeoutSeconds, queue: .mainQueue(), alternate: .single(nil))
}

private func transcribeSingleChunk(path: String, duration: Double, appLocale: String) -> Signal<String?, NoError> {
    // Use the app's language only: falling back to the device language would feed Arabic audio
    // into an English recognizer and store nonsense. resolveSupportedLocale already falls back to
    // the device locale when the app language itself has no Speech support.
    var locales: [String] = []
    if !appLocale.isEmpty {
        locales.append(appLocale)
    } else {
        locales.append(Locale.current.identifier)
    }

    var attempts: [(locale: String, onDevice: Bool)] = []
    for locale in locales where onDeviceRecognitionSupported(locale: locale) {
        attempts.append((locale, true))
    }
    for locale in locales {
        attempts.append((locale, false))
    }

    let timeoutSeconds = max(15.0, min(40.0, duration * 1.5 + 10.0))

    var signal: Signal<TranscriptionResult?, NoError> = .single(nil)
    for attempt in attempts {
        let attemptSignal = recognizeFile(path: path, locale: attempt.locale, preferOnDevice: attempt.onDevice, timeoutSeconds: timeoutSeconds)
        signal = signal |> mapToSignal { previous -> Signal<TranscriptionResult?, NoError> in
            if let previous = previous, !previous.text.isEmpty {
                return .single(previous)
            }
            return attemptSignal
        }
    }

    return signal
    |> map { result -> String? in
        guard let result = result else {
            return nil
        }
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

private func transcribeChunks(_ chunks: [PreparedAudioChunk], appLocale: String) -> Signal<LocallyTranscribedAudio?, NoError> {
    var signal: Signal<[String], NoError> = .single([])
    for chunk in chunks {
        let chunkSignal = transcribeSingleChunk(path: chunk.path, duration: chunk.duration, appLocale: appLocale)
        signal = signal |> mapToSignal { texts -> Signal<[String], NoError> in
            return chunkSignal |> map { text -> [String] in
                if let text = text, !text.isEmpty {
                    return texts + [text]
                }
                return texts
            }
        }
    }
    return signal
    |> map { texts -> LocallyTranscribedAudio? in
        let joined = texts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else {
            return nil
        }
        return LocallyTranscribedAudio(text: joined, isFinal: true)
    }
}

private func audioFileSize(_ path: String) -> Int? {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: path), let size = attributes[.size] as? NSNumber else {
        return nil
    }
    return size.intValue
}

private func audioDuration(_ asset: AVAsset) -> Double {
    let duration = CMTimeGetSeconds(asset.duration)
    if duration.isFinite && duration > 0.0 {
        return duration
    }
    return 0.0
}

private func splitAudioFile(path: String, asset: AVAsset, duration: Double) -> [PreparedAudioChunk] {
    let maximumChunkDuration: Double = 50.0
    guard duration > maximumChunkDuration + 5.0 else {
        return [PreparedAudioChunk(path: path, duration: max(duration, 1.0))]
    }

    var chunks: [PreparedAudioChunk] = []
    var start: Double = 0.0
    while start < duration {
        if duration - start < 0.5 {
            break
        }
        let end = min(start + maximumChunkDuration, duration)
        let outputPath = NSTemporaryDirectory() + "/joker-stt-chunk-\(UUID().uuidString).m4a"
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return [PreparedAudioChunk(path: path, duration: duration)]
        }
        exportSession.outputURL = URL(fileURLWithPath: outputPath)
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        if semaphore.wait(timeout: .now() + 60.0) == .timedOut {
            print("LocalTranscription: chunk export timed out at \(start)")
            exportSession.cancelExport()
            return [PreparedAudioChunk(path: path, duration: duration)]
        }
        if exportSession.status == .completed, let size = audioFileSize(outputPath), size > 0 {
            chunks.append(PreparedAudioChunk(path: outputPath, duration: end - start))
        } else {
            print("LocalTranscription: chunk export failed at \(start): \(String(describing: exportSession.error))")
            return [PreparedAudioChunk(path: path, duration: duration)]
        }
        start = end
    }
    if chunks.isEmpty {
        return [PreparedAudioChunk(path: path, duration: duration)]
    }
    return chunks
}

private func prepareAudio(path: String) -> Signal<[PreparedAudioChunk], NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVURLAsset(url: URL(fileURLWithPath: path))
            let sourcePath: String
            if !asset.tracks(withMediaType: .audio).isEmpty {
                sourcePath = path
            } else {
                let outputPath = NSTemporaryDirectory() + "/joker-stt-\(UUID().uuidString).m4a"
                let conversion = convertOpusToAAC(sourcePath: path, allocateTempFile: { return outputPath })
                |> timeout(60.0, queue: .mainQueue(), alternate: .single(nil))

                let semaphore = DispatchSemaphore(value: 0)
                var convertedPath: String?
                disposable.set(conversion.start(next: { result in
                    convertedPath = result
                }, completed: {
                    semaphore.signal()
                }))
                let _ = semaphore.wait(timeout: .now() + 70.0)

                guard let result = convertedPath, let size = audioFileSize(result), size > 0 else {
                    print("LocalTranscription: could not convert \(path) into a readable audio file")
                    Queue.mainQueue().async {
                        subscriber.putNext([])
                        subscriber.putCompletion()
                    }
                    return
                }
                sourcePath = result
            }

            let preparedAsset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
            let duration = audioDuration(preparedAsset)
            let chunks = splitAudioFile(path: sourcePath, asset: preparedAsset, duration: duration)
            print("LocalTranscription: prepared \(chunks.count) chunk(s) for \(path), duration=\(duration)")
            Queue.mainQueue().async {
                subscriber.putNext(chunks)
                subscriber.putCompletion()
            }
        }
        return disposable
    }
}

public struct LocallyTranscribedAudio {
    public var text: String
    public var isFinal: Bool
}

public func transcribeAudio(path: String, appLocale: String) -> Signal<LocallyTranscribedAudio?, NoError> {
    return speechAuthorizationSignal()
    |> mapToSignal { authorized -> Signal<LocallyTranscribedAudio?, NoError> in
        guard authorized else {
            print("LocalTranscription: speech recognition is not authorized")
            return .single(nil)
        }
        return prepareAudio(path: path)
        |> mapToSignal { chunks -> Signal<LocallyTranscribedAudio?, NoError> in
            guard !chunks.isEmpty else {
                return .single(nil)
            }
            return transcribeChunks(chunks, appLocale: appLocale)
        }
    }
}

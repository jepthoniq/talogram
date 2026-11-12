import Foundation
import SwiftSignalKit
import Speech

private var sharedRecognizers: [String: NSObject] = [:]

private struct TranscriptionResult {
    var text: String
    var confidence: Float
    var isFinal: Bool
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
        }
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

private func transcribeAudio(path: String, locale: String) -> Signal<TranscriptionResult?, NoError> {
    return Signal { subscriber in
        let disposable = MetaDisposable()

        if #available(iOS 13.0, *) {
            SFSpeechRecognizer.requestAuthorization { status in
                Queue.mainQueue().async {
                    switch status {
                    case .notDetermined, .restricted, .denied:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    case .authorized:
                        guard let resolvedLocale = resolveSupportedLocale(locale) else {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                            return
                        }
                        let speechRecognizer: SFSpeechRecognizer
                        let key = resolvedLocale.identifier
                        if let sharedRecognizer = sharedRecognizers[key] as? SFSpeechRecognizer {
                            speechRecognizer = sharedRecognizer
                        } else {
                            guard let speechRecognizerValue = SFSpeechRecognizer(locale: resolvedLocale), speechRecognizerValue.isAvailable else {
                                subscriber.putNext(nil)
                                subscriber.putCompletion()
                                return
                            }
                            speechRecognizerValue.defaultTaskHint = .dictation
                            sharedRecognizers[key] = speechRecognizerValue
                            speechRecognizer = speechRecognizerValue
                        }

                        let tempFilePath = NSTemporaryDirectory() + "/\(UInt64.random(in: 0 ... UInt64.max)).m4a"
                        let _ = try? FileManager.default.copyItem(atPath: path, toPath: tempFilePath)

                        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: tempFilePath))
                        if #available(iOS 16.0, *) {
                            request.addsPunctuation = true
                        }
                        // Only run on-device when the device and locale actually support it; otherwise fall back to the server recognizer (requires network).
                        request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
                        request.shouldReportPartialResults = false

                        let task = speechRecognizer.recognitionTask(with: request, resultHandler: { result, error in
                            if let result = result {
                                var confidence: Float = 0.0
                                for segment in result.bestTranscription.segments {
                                    confidence += segment.confidence
                                }
                                if result.bestTranscription.segments.count > 0 {
                                    confidence /= Float(result.bestTranscription.segments.count)
                                }
                                subscriber.putNext(TranscriptionResult(text: result.bestTranscription.formattedString, confidence: confidence, isFinal: result.isFinal))

                                if result.isFinal {
                                    subscriber.putCompletion()
                                }
                            } else {
                                print("transcribeAudio: locale: \(key), error: \(String(describing: error))")

                                subscriber.putNext(nil)
                                subscriber.putCompletion()
                            }
                        })

                        disposable.set(ActionDisposable {
                            task.cancel()
                        })
                    @unknown default:
                        subscriber.putNext(nil)
                        subscriber.putCompletion()
                    }
                }
            }
        } else {
            subscriber.putNext(nil)
            subscriber.putCompletion()
        }

        return disposable
    }
    |> runOn(.mainQueue())
}

public struct LocallyTranscribedAudio {
    public var text: String
    public var isFinal: Bool
}

public func transcribeAudio(path: String, appLocale: String) -> Signal<LocallyTranscribedAudio?, NoError> {
    var locales: [String] = []
    // Prefer the app's base language (e.g. "ar"), fall back to the device locale (e.g. "ar_EG").
    if !appLocale.isEmpty {
        locales.append(appLocale)
    }
    if !locales.contains(Locale.current.identifier) {
        locales.append(Locale.current.identifier)
    }
    if locales.isEmpty {
        locales.append("en")
    }
    var signals: [Signal<TranscriptionResult?, NoError>] = []
    for locale in locales {
        signals.append(transcribeAudio(path: path, locale: locale))
    }
    var resultSignal: Signal<[TranscriptionResult?], NoError> = .single([])
    for signal in signals {
        resultSignal = resultSignal |> mapToSignal { result -> Signal<[TranscriptionResult?], NoError> in
            return signal |> map { next in
                return result + [next]
            }
        }
    }

    return resultSignal
    |> map { results -> LocallyTranscribedAudio? in
        let sortedResults = results.compactMap({ $0 }).sorted(by: { lhs, rhs in
            return lhs.confidence > rhs.confidence
        })
        return sortedResults.first.flatMap { result -> LocallyTranscribedAudio in
            return LocallyTranscribedAudio(text: result.text, isFinal: result.isFinal)
        }
    }
}

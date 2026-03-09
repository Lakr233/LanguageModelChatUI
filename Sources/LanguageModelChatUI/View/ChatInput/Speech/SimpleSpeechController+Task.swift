//
//  SimpleSpeechController+Task.swift
//  LanguageModelChatUI
//

import AVFAudio
import Speech
import UIKit

private nonisolated func requestSpeechAuthorizationAsync() async -> SFSpeechRecognizerAuthorizationStatus {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status)
        }
    }
}

private nonisolated func requestRecordPermissionAsync() async -> Bool {
    await withCheckedContinuation { continuation in
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private nonisolated func installRecognitionTap(
    inputNode: AVAudioInputNode,
    recognitionRequest: SFSpeechAudioBufferRecognitionRequest
) {
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
        recognitionRequest.append(buffer)
    }
}

extension SimpleSpeechController {
    @objc func stopTranscriptButton() {
        doneButton.isEnabled = false
        doneButton.setTitle(String.localized("Transcript Stopped"), for: .normal)
        stopTranscript()
        var text = textView.text ?? ""
        if text.hasSuffix(placeholderText) {
            text.removeLast(placeholderText.count)
        }
        callback(text)
        dismiss(animated: true)
    }

    func startTranscript() {
        Task { @MainActor in
            do {
                try await startTranscriptEx()
                doneButton.doWithAnimation { [self] in
                    doneButton.isEnabled = true
                }
                doneButton.setTitle(String.localized("Stop Transcript"), for: .normal)
            } catch {
                stopTranscript()
                onErrorCallback(error)
            }
        }
    }

    func stopTranscript() {
        for item in sessionItems {
            if let task = item as? SFSpeechRecognitionTask {
                task.cancel()
            }
        }
        sessionItems.removeAll()
    }

    private func startTranscriptEx() async throws {
        let speechAuthorization = await requestSpeechAuthorizationAsync()
        guard speechAuthorization == .authorized else {
            throw NSError(domain: "SpeechRecognizer", code: 0, userInfo: [
                NSLocalizedDescriptionKey: String.localized("Speech recognizer is not authorized."),
            ])
        }

        let micPermissionGranted = await requestRecordPermissionAsync()
        guard micPermissionGranted else {
            throw NSError(domain: "SpeechRecognizer", code: 0, userInfo: [
                NSLocalizedDescriptionKey: String.localized("Microphone is not authorized."),
            ])
        }

        let preferredAppLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        let preferredLocaleIdentifier = (preferredAppLanguage != "en") ? preferredAppLanguage : Locale.preferredLanguages.first ?? "en"
        let localeID = preferredLocaleIdentifier.replacingOccurrences(of: "_", with: "-")
        let speechLocale = Locale(identifier: localeID)

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false

        guard let speechRecognizer = SFSpeechRecognizer(locale: speechLocale) else {
            throw NSError(domain: "SpeechRecognizer", code: 0, userInfo: [
                NSLocalizedDescriptionKey: String.localized("Speech recognizer is not available."),
            ])
        }

        let recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
            guard let self, let result else { return }
            Task { @MainActor in
                self.textView.text = result.bestTranscription.formattedString
                self.textView.doWithAnimation {
                    self.textView.contentOffset = .init(
                        x: 0,
                        y: max(0, self.textView.contentSize.height - self.textView.bounds.size.height)
                    )
                }
            }
        }

        installRecognitionTap(inputNode: inputNode, recognitionRequest: recognitionRequest)

        audioEngine.prepare()
        try audioEngine.start()

        sessionItems.append(audioEngine)
        sessionItems.append(inputNode)
        sessionItems.append(recognitionTask)
    }
}

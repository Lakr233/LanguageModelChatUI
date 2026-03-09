//
//  BalancedEmitter.swift
//  LanguageModelChatUI
//

import Foundation

@MainActor
final class BalancedEmitter {
    private var buffer: String = ""
    private var duration: Double
    private var frequency: Int
    private var batchSize: Int = 1
    private var drainTask: Task<Void, Never>?

    private let onEmit: @MainActor (String) async -> Void

    init(
        duration: Double = 1,
        frequency: Int = 30,
        onEmit: @escaping @MainActor (String) async -> Void
    ) {
        self.duration = duration
        self.frequency = frequency
        self.onEmit = onEmit
    }

    func update(duration: Double? = nil, frequency: Int? = nil) {
        if let duration, duration > 0 {
            self.duration = duration
        }
        if let frequency, frequency > 0 {
            self.frequency = frequency
        }
        recalculateBatchSize()
    }

    func add(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        buffer += chunk
        recalculateBatchSize()
        dispatchLoopIfRequired()
    }

    func wait() async {
        await drainTask?.value
    }

    func cancel() {
        buffer = ""
        drainTask?.cancel()
        drainTask = nil
    }

    private func recalculateBatchSize() {
        batchSize = max(1, Int(ceil(Double(buffer.count) / Double(max(frequency, 1)))))
    }

    private func dispatchLoopIfRequired() {
        guard drainTask == nil else { return }

        drainTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { drainTask = nil }

            let stepDelay = (duration * 1000) / Double(max(frequency, 1))
            while !Task.isCancelled, !buffer.isEmpty {
                let emitCount = min(batchSize, buffer.count)
                let emitText = String(buffer.prefix(emitCount))
                buffer.removeFirst(emitText.count)
                await onEmit(emitText)

                guard !buffer.isEmpty else { break }
                try? await Task.sleep(for: .milliseconds(Int(stepDelay)))
            }
        }
    }
}

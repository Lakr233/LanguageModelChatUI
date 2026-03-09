import Foundation
import ServerEvent

open class BaseChatClient: ChatClient, @unchecked Sendable {
    public let errorCollector: ErrorCollector

    public enum Error: Swift.Error {
        case notImplemented
    }

    public init(errorCollector: ErrorCollector = .new()) {
        self.errorCollector = errorCollector
    }

    open func chat(body: ChatRequestBody) async throws -> ChatResponse {
        try await ChatResponse(chunks: chatChunks(body: body))
    }

    /// Merges adjacent assistant messages then calls `provideStreamingChat(body:)`.
    /// Subclasses must override `provideStreamingChat(body:)`, not this method.
    public final func streamingChat(body: ChatRequestBody) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        try await provideStreamingChat(body: body.mergingAdjacentAssistantMessages())
    }

    /// Override in subclasses to provide the actual streaming implementation.
    /// The `body` received here has already had adjacent assistant messages merged.
    open func provideStreamingChat(body _: ChatRequestBody) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        throw Error.notImplemented
    }

    // MARK: - Error collection

    /// Human-readable description of the remote endpoint, used in connection failure messages.
    open var connectionFailureMessage: String {
        String(localized: "Unable to connect to the server.")
    }

    /// Extract a user-facing error message from a raw HTTP error response body.
    /// Subclasses override this to parse provider-specific error formats.
    open func extractConnectionError(from _: Data?, statusCode: Int) -> String {
        String(localized: "Connection error: \(statusCode)")
    }

    func collect(error: Swift.Error) async {
        if let error = error as? EventSourceError {
            switch error {
            case .undefinedConnectionError:
                await errorCollector.collect(connectionFailureMessage)
            case let .connectionError(statusCode, response):
                let message = extractConnectionError(from: response, statusCode: statusCode)
                await errorCollector.collect(message)
            case .alreadyConsumed:
                assertionFailure()
            }
            return
        }
        await errorCollector.collect(error.localizedDescription)
        logger.error("collected error: \(error.localizedDescription)")
    }
}

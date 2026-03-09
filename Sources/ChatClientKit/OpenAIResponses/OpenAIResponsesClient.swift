import Foundation
import ServerEvent

open class OpenAIResponsesClient: BaseChatClient, @unchecked Sendable {
    public let model: String
    open var baseURL: String?
    open var path: String?
    open var apiKey: String?
    open var defaultHeaders: [String: String]
    open var requestCustomization: [String: Any]

    public enum Error: Swift.Error {
        case invalidURL
        case invalidApiKey
        case invalidData
    }

    let eventSourceFactory: EventSourceProducing
    let chunkDecoderFactory: @Sendable () -> JSONDecoding
    let errorExtractor: OpenAIResponsesErrorExtractor
    let requestTransformer: OpenAIResponsesRequestTransformer

    public convenience init(
        model: String,
        baseURL: String? = nil,
        path: String? = nil,
        apiKey: String? = nil,
        defaultHeaders: [String: String] = [:],
        requestCustomization: [String: Any] = [:]
    ) {
        self.init(
            model: model,
            baseURL: baseURL,
            path: path,
            apiKey: apiKey,
            defaultHeaders: defaultHeaders,
            requestCustomization: requestCustomization,
            dependencies: .live
        )
    }

    public init(
        model: String,
        baseURL: String? = nil,
        path: String? = nil,
        apiKey: String? = nil,
        defaultHeaders: [String: String] = [:],
        requestCustomization: [String: Any] = [:],
        errorCollector: ErrorCollector = .new(),
        dependencies: RemoteClientDependencies
    ) {
        self.model = model
        self.baseURL = baseURL
        self.path = path
        self.apiKey = apiKey
        self.defaultHeaders = defaultHeaders
        self.requestCustomization = requestCustomization
        eventSourceFactory = dependencies.eventSourceFactory
        chunkDecoderFactory = dependencies.chunkDecoderFactory
        errorExtractor = dependencies.errorExtractor
        requestTransformer = OpenAIResponsesRequestTransformer()
        super.init(errorCollector: errorCollector)
    }

    override open func provideStreamingChat(
        body: ChatRequestBody
    ) async throws -> AnyAsyncSequence<ChatResponseChunk> {
        let requestBody = applyModelSettings(to: body, streaming: true)
        let request = try makeURLRequest(body: requestBody)
        let this = self
        logger.info("starting streaming responses request to model: \(this.model) with \(body.messages.count) messages, temperature: \(body.temperature ?? 1.0)")

        let processor = OpenAIResponsesStreamProcessor(
            eventSourceFactory: eventSourceFactory,
            chunkDecoder: chunkDecoderFactory(),
            errorExtractor: errorExtractor
        )

        return processor.stream(request: request) { [weak self] error in
            await self?.collect(error: error)
        }
    }

    override open func extractConnectionError(from response: Data?, statusCode: Int) -> String {
        if let data = response, let decodedError = errorExtractor.extractError(from: data) {
            return decodedError.localizedDescription
        }
        return String(localized: "Connection error: \(statusCode)")
    }
}

extension OpenAIResponsesClient {
    func makeRequestBuilder() -> OpenAIResponsesRequestBuilder {
        OpenAIResponsesRequestBuilder(
            baseURL: baseURL,
            path: path,
            apiKey: apiKey,
            defaultHeaders: defaultHeaders
        )
    }

    func makeURLRequest(body: OpenAIResponsesRequestBody) throws -> URLRequest {
        let builder = makeRequestBuilder()
        return try builder.makeRequest(body: body, requestCustomization: requestCustomization)
    }

    func applyModelSettings(to body: ChatRequestBody, streaming: Bool) -> OpenAIResponsesRequestBody {
        var requestBody = body
        requestBody.model = model
        requestBody.stream = streaming
        return requestTransformer.makeRequestBody(from: requestBody, model: model, stream: streaming)
    }
}

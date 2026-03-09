//
//  OpenAICompatibleRequestBuilder.swift
//  ChatClientKit
//
//  Created by GPT-5 Codex on 2025/11/10.
//

import Foundation

struct OpenAICompatibleRequestBuilder {
    let baseURL: String?
    let path: String?
    let apiKey: String?
    var defaultHeaders: [String: String]

    let encoder: JSONEncoder

    init(
        baseURL: String?,
        path: String?,
        apiKey: String?,
        defaultHeaders: [String: String],
        encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            return encoder
        }()
    ) {
        self.baseURL = baseURL
        self.path = path
        self.apiKey = apiKey
        self.defaultHeaders = defaultHeaders
        self.encoder = encoder
    }

    func makeRequest(
        body: ChatRequestBody,
        requestCustomization: [String: Any]
    ) throws -> URLRequest {
        guard let baseURL else {
            logger.error("invalid base URL")
            throw OpenAICompatibleClient.Error.invalidURL
        }

        var normalizedPath = path ?? ""
        if !normalizedPath.isEmpty, !normalizedPath.starts(with: "/") {
            normalizedPath = "/\(normalizedPath)"
        }

        guard var baseComponents = URLComponents(string: baseURL),
              let pathComponents = URLComponents(string: normalizedPath)
        else {
            logger.error(
                "failed to parse URL components from baseURL: \(baseURL), path: \(normalizedPath)"
            )
            throw OpenAICompatibleClient.Error.invalidURL
        }

        if !pathComponents.path.isEmpty {
            let normalizedBasePath = baseComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let normalizedRequestPath = pathComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if normalizedBasePath.caseInsensitiveCompare(normalizedRequestPath) != .orderedSame,
               !normalizedBasePath.hasSuffix("/\(normalizedRequestPath)")
            {
                let separator = baseComponents.path.hasSuffix("/") ? "" : "/"
                baseComponents.path += separator + normalizedRequestPath
            }
        }
        baseComponents.queryItems = pathComponents.queryItems

        guard let url = baseComponents.url else {
            logger.error("failed to construct final URL from components")
            throw OpenAICompatibleClient.Error.invalidURL
        }

        logger.debug("constructed request URL: \(url.absoluteString)")
        logger.info("outbound chat payload summary: \(body.debugSummary)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        logger.info("serialized chat request bytes: \(request.httpBody?.count ?? 0)")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedApiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedApiKey, !trimmedApiKey.isEmpty {
            request.setValue("Bearer \(trimmedApiKey)", forHTTPHeaderField: "Authorization")
        }

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if !requestCustomization.isEmpty {
            var originalDictionary: [String: Any] = [:]
            if let body = request.httpBody,
               let dictionary = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            {
                originalDictionary = dictionary
            }
            for (key, value) in requestCustomization {
                originalDictionary[key] = value
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: originalDictionary, options: [.sortedKeys])
            logger.info("serialized chat request bytes after customization: \(request.httpBody?.count ?? 0)")
        }

        return request
    }
}

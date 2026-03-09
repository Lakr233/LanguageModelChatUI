//
//  OpenAIResponsesRequestBuilder.swift
//  ChatClientKit
//
//  Created by Henri on 2025/12/2.
//

import Foundation

struct OpenAIResponsesRequestBuilder {
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
        body: OpenAIResponsesRequestBody,
        requestCustomization: [String: Any]
    ) throws -> URLRequest {
        guard let baseURL else {
            logger.error("invalid base URL for responses client")
            throw OpenAIResponsesClient.Error.invalidURL
        }

        var normalizedPath = path ?? ""
        if !normalizedPath.isEmpty, !normalizedPath.starts(with: "/") {
            normalizedPath = "/\(normalizedPath)"
        }

        guard var baseComponents = URLComponents(string: baseURL),
              let pathComponents = URLComponents(string: normalizedPath)
        else {
            logger.error("failed to parse URL components from baseURL: \(baseURL), path: \(normalizedPath)")
            throw OpenAIResponsesClient.Error.invalidURL
        }

        baseComponents.path += pathComponents.path
        baseComponents.queryItems = pathComponents.queryItems

        guard let url = baseComponents.url else {
            logger.error("failed to construct final URL from components for responses client")
            throw OpenAIResponsesClient.Error.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
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
        }

        logger.debug("constructed responses request URL: \(url.absoluteString)")
        return request
    }
}

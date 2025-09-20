//
//  ProxyService.swift
//  clippy
//
//  Created by Claude on 20.09.2025.
//

import Foundation

class ProxyService: ObservableObject {
    private let baseURL = "https://proxy.clippy.it.com"
    private let authenticationService: AuthenticationService

    init(authenticationService: AuthenticationService) {
        self.authenticationService = authenticationService
    }

    func transformText(_ text: String, instruction: String, completion: @escaping (Result<String, ProxyError>) -> Void) {
        guard let token = authenticationService.getValidToken() else {
            completion(.failure(.notAuthenticated))
            return
        }

        // Map instruction to proxy prompt key
        let promptKey = mapInstructionToPromptKey(instruction)

        guard let url = URL(string: "\(baseURL)/ai/gemini") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let requestBody = ProxyRequest(prompt: promptKey, text: text)

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(.encodingError))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.notAuthenticated))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let response = try JSONDecoder().decode(ProxyResponse.self, from: data)
                completion(.success(response.text))
            } catch {
                completion(.failure(.decodingError))
            }
        }.resume()
    }

    private func mapInstructionToPromptKey(_ instruction: String) -> String {
        // Map common instruction patterns to proxy prompt keys
        let lowercased = instruction.lowercased()

        if lowercased.contains("grammar") || lowercased.contains("spelling") || lowercased.contains("punctuation") {
            return "fix_grammar"
        } else if lowercased.contains("professional") || lowercased.contains("formal") || lowercased.contains("business") {
            return "make_professional"
        } else if lowercased.contains("shorter") || lowercased.contains("concise") || lowercased.contains("brief") {
            return "make_shorter"
        } else {
            // Default to grammar fixing for unknown instructions
            return "fix_grammar"
        }
    }
}

// MARK: - Data Models

private struct ProxyRequest: Codable {
    let prompt: String
    let text: String
}

private struct ProxyResponse: Codable {
    let text: String
}

// MARK: - Error Types

enum ProxyError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case encodingError
    case decodingError
    case networkError(String)
    case invalidResponse
    case noData
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in first."
        case .invalidURL:
            return "Invalid proxy URL."
        case .encodingError:
            return "Failed to encode request data."
        case .decodingError:
            return "Failed to decode response data."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        case .noData:
            return "No data received from server."
        case .serverError(let code):
            return "Server error with code: \(code)"
        }
    }
}
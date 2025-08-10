import Foundation

enum APIError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case rateLimitExceeded
    case invalidAPIKey
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured for the selected provider"
        case .invalidResponse:
            return "Invalid response from API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

final class APIServiceManager {
    let settingsManager: SettingsManager
    private let urlSession: URLSession
    
    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration)
    }
    
    func hasValidAPIKey() -> Bool {
        return settingsManager.hasValidAPIKey()
    }
    
    func transformText(
        _ text: String,
        instruction: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard settingsManager.hasValidAPIKey(),
              let apiKey = settingsManager.getCurrentAPIKey() else {
            completion(.failure(.noAPIKey))
            return
        }
        
        switch settingsManager.selectedProvider {
        case .openai:
            transformWithOpenAI(text: text, instruction: instruction, apiKey: apiKey, completion: completion)
        case .gemini:
            transformWithGemini(text: text, instruction: instruction, apiKey: apiKey, completion: completion)
        case .claude:
            transformWithClaude(text: text, instruction: instruction, apiKey: apiKey, completion: completion)
        }
    }
    
    private func transformWithOpenAI(
        text: String,
        instruction: String,
        apiKey: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(.failure(.unknown("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": "You are a text transformation assistant. Follow the user's instructions precisely and return ONLY the single best transformed text as a direct replacement. Do not provide multiple options, explanations, or any additional commentary. Return only the transformed text that can directly replace the original."],
            ["role": "user", "content": "\(instruction):\n\n\(text)"]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.3
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.unknown("Failed to encode request")))
            return
        }
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 401:
                    completion(.failure(.invalidAPIKey))
                    return
                case 429:
                    completion(.failure(.rateLimitExceeded))
                    return
                case 200...299:
                    break
                default:
                    completion(.failure(.unknown("HTTP \(httpResponse.statusCode)")))
                    return
                }
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let choices = json?["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
    
    private func transformWithGemini(
        text: String,
        instruction: String,
        apiKey: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent") else {
            completion(.failure(.unknown("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-goog-api-key")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "You are a text transformation assistant. Follow the user's instructions precisely and return ONLY the single best transformed text as a direct replacement. Do not provide multiple options, explanations, or any additional commentary. Return only the transformed text that can directly replace the original.\n\n\(instruction):\n\n\(text)"]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.unknown("Failed to encode request")))
            return
        }
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 400:
                    completion(.failure(.invalidAPIKey))
                    return
                case 429:
                    completion(.failure(.rateLimitExceeded))
                    return
                case 200...299:
                    break
                default:
                    completion(.failure(.unknown("HTTP \(httpResponse.statusCode)")))
                    return
                }
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let candidates = json?["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let text = firstPart["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
    
    private func transformWithClaude(
        text: String,
        instruction: String,
        apiKey: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            completion(.failure(.unknown("Invalid URL")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 2000,
            "messages": [
                [
                    "role": "user",
                    "content": "You are a text transformation assistant. Follow the user's instructions precisely and return ONLY the single best transformed text as a direct replacement. Do not provide multiple options, explanations, or any additional commentary. Return only the transformed text that can directly replace the original.\n\n\(instruction):\n\n\(text)"
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.unknown("Failed to encode request")))
            return
        }
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                switch httpResponse.statusCode {
                case 401:
                    completion(.failure(.invalidAPIKey))
                    return
                case 429:
                    completion(.failure(.rateLimitExceeded))
                    return
                case 200...299:
                    break
                default:
                    completion(.failure(.unknown("HTTP \(httpResponse.statusCode)")))
                    return
                }
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let content = json?["content"] as? [[String: Any]],
                   let firstContent = content.first,
                   let text = firstContent["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
}
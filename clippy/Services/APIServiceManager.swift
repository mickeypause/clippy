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
    private let urlSession: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration)
    }
    
    func hasValidAPIKey() -> Bool {
        return true // Always true since we have a hardcoded API key
    }
    
    func transformText(
        _ text: String,
        instruction: String,
        completion: @escaping (Result<String, APIError>) -> Void
    ) {
        transformWithGemini(text: text, instruction: instruction, apiKey: SettingsManager.geminiAPIKey, completion: completion)
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
}

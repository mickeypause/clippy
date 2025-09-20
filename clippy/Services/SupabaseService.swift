//
//  SupabaseService.swift
//  clippy
//
//  Created by Claude on 20.09.2025.
//

import Foundation

class SupabaseService: ObservableObject {
    private let supabaseURL = "https://xokfqqulknpnlxjxeiaa.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inhva2ZxcXVsa25wbmx4anhlaWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MzYzODksImV4cCI6MjA3MDUxMjM4OX0.28a7OjZQPeyriAWrZQYrytY8smGvlO5_YIt4d_4JV2I"

    private var authenticationService: AuthenticationService?

    @Published var prompts: [UserPrompt] = []
    @Published var isLoading = false
    @Published var error: String?

    struct UserPrompt: Codable, Identifiable {
        let id: String
        let name: String
        let userId: String
        let createdAt: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case userId = "user_id"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    struct CreatePromptRequest: Codable {
        let name: String
    }

    init(authenticationService: AuthenticationService) {
        self.authenticationService = authenticationService
    }

    // MARK: - Public Methods

    func fetchPrompts() async {
        guard let token = authenticationService?.getValidToken() else {
            DispatchQueue.main.async {
                self.error = "Authentication required"
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/user_prompts?select=*&order=created_at.desc")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let prompts = try JSONDecoder().decode([UserPrompt].self, from: data)
                    DispatchQueue.main.async {
                        self.prompts = prompts
                        self.isLoading = false
                    }
                } else {
                    throw SupabaseError.apiError("Failed to fetch prompts: \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func createPrompt(name: String) async {
        guard let token = authenticationService?.getValidToken() else {
            DispatchQueue.main.async {
                self.error = "Authentication required"
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.error = nil
        }

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/user_prompts")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let createRequest = CreatePromptRequest(name: name)
            request.httpBody = try JSONEncoder().encode(createRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    let newPrompts = try JSONDecoder().decode([UserPrompt].self, from: data)
                    DispatchQueue.main.async {
                        self.prompts.insert(contentsOf: newPrompts, at: 0)
                        self.isLoading = false
                    }
                } else {
                    throw SupabaseError.apiError("Failed to create prompt: \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func deletePrompt(id: String) async {
        guard let token = authenticationService?.getValidToken() else {
            DispatchQueue.main.async {
                self.error = "Authentication required"
            }
            return
        }

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/user_prompts?id=eq.\(id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    DispatchQueue.main.async {
                        self.prompts.removeAll { $0.id == id }
                    }
                } else {
                    throw SupabaseError.apiError("Failed to delete prompt: \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
        }
    }

    func updatePrompt(id: String, name: String) async {
        guard let token = authenticationService?.getValidToken() else {
            DispatchQueue.main.async {
                self.error = "Authentication required"
            }
            return
        }

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/user_prompts?id=eq.\(id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")

            let updateRequest = CreatePromptRequest(name: name)
            request.httpBody = try JSONEncoder().encode(updateRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let updatedPrompts = try JSONDecoder().decode([UserPrompt].self, from: data)
                    if let updatedPrompt = updatedPrompts.first {
                        DispatchQueue.main.async {
                            if let index = self.prompts.firstIndex(where: { $0.id == id }) {
                                self.prompts[index] = updatedPrompt
                            }
                        }
                    }
                } else {
                    throw SupabaseError.apiError("Failed to update prompt: \(httpResponse.statusCode)")
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error.localizedDescription
            }
        }
    }

    func testConnection() async -> Bool {
        guard let token = authenticationService?.getValidToken() else {
            return false
        }

        do {
            let url = URL(string: "\(supabaseURL)/rest/v1/user_prompts?select=count")!
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }

            return false
        } catch {
            return false
        }
    }
}

// MARK: - Error Types

enum SupabaseError: Error {
    case apiError(String)
    case networkError(String)
    case authenticationError(String)

    var localizedDescription: String {
        switch self {
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        }
    }
}
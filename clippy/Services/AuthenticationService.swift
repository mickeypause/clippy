//
//  AuthenticationService.swift
//  clippy
//
//  Created by Claude on 20.09.2025.
//

import Foundation
import Security
import AppKit

class AuthenticationService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: User?
    @Published var authenticationError: String?

    private let keychainService = "com.clippy.app"
    private let tokenKey = "jwt_token"
    private let userKey = "user_data"
    private let webAuthURL = "http://localhost:3001/auth/native?source=native"

    struct User: Codable {
        let id: String
        let email: String
        let firstName: String?
        let lastName: String?
    }

    init() {
        checkAuthenticationStatus()
    }

    // MARK: - Public Methods

    func signIn() {
        guard let url = URL(string: webAuthURL) else {
            authenticationError = "Invalid authentication URL"
            return
        }

        NSWorkspace.shared.open(url)
    }

    func signOut() {
        deleteTokenFromKeychain()
        deleteUserFromKeychain()
        isAuthenticated = false
        user = nil
        authenticationError = nil
    }

    func handleAuthenticationCallback(url: URL) {
        guard url.scheme == "clippyapp",
              url.host == "auth" else {
            authenticationError = "Invalid callback URL"
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else {
            authenticationError = "Missing authentication data"
            return
        }

        var token: String?
        var status: String?
        var userId: String?

        for item in queryItems {
            switch item.name {
            case "token":
                token = item.value
            case "status":
                status = item.value
            case "user_id":
                userId = item.value
            default:
                break
            }
        }

        guard let jwtToken = token,
              status == "success" else {
            authenticationError = "Authentication failed"
            return
        }

        // Validate and store the token
        if validateJWTToken(jwtToken) {
            storeTokenInKeychain(jwtToken)

            // Fetch user data using the token
            fetchUserData(token: jwtToken) { [weak self] userData in
                DispatchQueue.main.async {
                    if let userData = userData {
                        self?.user = userData
                        self?.storeUserInKeychain(userData)
                        self?.isAuthenticated = true
                        self?.authenticationError = nil
                    } else {
                        self?.authenticationError = "Failed to fetch user data"
                    }
                }
            }
        } else {
            authenticationError = "Invalid authentication token"
        }
    }

    func getValidToken() -> String? {
        guard let token = getTokenFromKeychain() else {
            return nil
        }

        if isTokenExpired(token) {
            // Token is expired, trigger re-authentication
            signOut()
            return nil
        }

        return token
    }

    // MARK: - Private Methods

    private func checkAuthenticationStatus() {
        guard let token = getTokenFromKeychain() else {
            isAuthenticated = false
            return
        }

        if isTokenExpired(token) {
            signOut()
            return
        }

        // Load user data from keychain
        if let userData = getUserFromKeychain() {
            user = userData
            isAuthenticated = true
        } else {
            // Token exists but no user data, fetch it
            fetchUserData(token: token) { [weak self] userData in
                DispatchQueue.main.async {
                    if let userData = userData {
                        self?.user = userData
                        self?.storeUserInKeychain(userData)
                        self?.isAuthenticated = true
                    } else {
                        self?.signOut()
                    }
                }
            }
        }
    }

    private func validateJWTToken(_ token: String) -> Bool {
        // Basic JWT format validation
        let parts = token.components(separatedBy: ".")
        return parts.count == 3
    }

    private func isTokenExpired(_ token: String) -> Bool {
        // Parse JWT to check expiration
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return true }

        let payload = parts[1]
        var base64 = payload

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }

        return Date(timeIntervalSince1970: exp) < Date()
    }

    private func fetchUserData(token: String, completion: @escaping (User?) -> Void) {
        // In a real implementation, you might want to fetch user data from your API
        // For now, we'll decode it from the JWT if possible
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            completion(nil)
            return
        }

        let payload = parts[1]
        var base64 = payload

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userId = json["sub"] as? String else {
            completion(nil)
            return
        }

        // Create a basic user object from JWT claims
        let user = User(
            id: userId,
            email: json["email"] as? String ?? "",
            firstName: json["given_name"] as? String,
            lastName: json["family_name"] as? String
        )

        completion(user)
    }

    // MARK: - Keychain Methods

    private func storeTokenInKeychain(_ token: String) {
        let data = token.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: tokenKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func storeUserInKeychain(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userKey,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }

    private func getUserFromKeychain() -> User? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return nil
        }

        return user
    }

    private func deleteUserFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: userKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}
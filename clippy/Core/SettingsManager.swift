import Foundation
import Combine

enum AIProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case claude = "Claude"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .gemini: return "AIza..."
        case .claude: return "sk-ant-..."
        }
    }
}

final class SettingsManager: ObservableObject {
    @Published var selectedProvider: AIProvider = .openai
    @Published var openAIKey: String = ""
    @Published var geminiKey: String = ""
    @Published var claudeKey: String = ""
    
    private let keychain = KeychainManager()
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let openAIKey = "openai_key"
        static let geminiKey = "gemini_key"
        static let claudeKey = "claude_key"
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let providerRawValue = userDefaults.string(forKey: Keys.selectedProvider),
           let provider = AIProvider(rawValue: providerRawValue) {
            selectedProvider = provider
        }
        
        openAIKey = keychain.getString(forKey: Keys.openAIKey) ?? ""
        geminiKey = keychain.getString(forKey: Keys.geminiKey) ?? ""
        claudeKey = keychain.getString(forKey: Keys.claudeKey) ?? ""
    }
    
    func saveSettings() {
        userDefaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        
        keychain.setString(openAIKey, forKey: Keys.openAIKey)
        keychain.setString(geminiKey, forKey: Keys.geminiKey)
        keychain.setString(claudeKey, forKey: Keys.claudeKey)
    }
    
    func getCurrentAPIKey() -> String? {
        switch selectedProvider {
        case .openai: return openAIKey.isEmpty ? nil : openAIKey
        case .gemini: return geminiKey.isEmpty ? nil : geminiKey
        case .claude: return claudeKey.isEmpty ? nil : claudeKey
        }
    }
    
    func hasValidAPIKey() -> Bool {
        getCurrentAPIKey() != nil
    }
}

final class KeychainManager {
    func setString(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == noErr,
              let data = dataTypeRef as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
}
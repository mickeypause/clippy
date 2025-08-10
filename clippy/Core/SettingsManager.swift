import Foundation
import Combine
import ServiceManagement

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
    @Published var launchAtStartup: Bool = false
    
    private let keychain = KeychainManager()
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let selectedProvider = "selectedProvider"
        static let openAIKey = "openai_key"
        static let geminiKey = "gemini_key"
        static let claudeKey = "claude_key"
        static let launchAtStartup = "launchAtStartup"
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        if let providerRawValue = userDefaults.string(forKey: Keys.selectedProvider),
           let provider = AIProvider(rawValue: providerRawValue) {
            selectedProvider = provider
        }
        
        launchAtStartup = userDefaults.bool(forKey: Keys.launchAtStartup)
        
        openAIKey = keychain.getString(forKey: Keys.openAIKey) ?? ""
        geminiKey = keychain.getString(forKey: Keys.geminiKey) ?? ""
        claudeKey = keychain.getString(forKey: Keys.claudeKey) ?? ""
    }
    
    func saveSettings() {
        userDefaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        userDefaults.set(launchAtStartup, forKey: Keys.launchAtStartup)
        
        keychain.setString(openAIKey, forKey: Keys.openAIKey)
        keychain.setString(geminiKey, forKey: Keys.geminiKey)
        keychain.setString(claudeKey, forKey: Keys.claudeKey)
        
        updateLaunchAtStartupStatus()
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
    
    private func updateLaunchAtStartupStatus() {
        if launchAtStartup {
            enableLaunchAtStartup()
        } else {
            disableLaunchAtStartup()
        }
    }
    
    private func enableLaunchAtStartup() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("Failed to register launch at startup: \(error)")
            }
        } else {
            let _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        }
    }
    
    private func disableLaunchAtStartup() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("Failed to unregister launch at startup: \(error)")
            }
        } else {
            let _ = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
        }
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
import Foundation
import Combine
import ServiceManagement

final class SettingsManager: ObservableObject {
    @Published var launchAtStartup: Bool = true {
        didSet { autoSave() }
    }
    @Published var autoUpdates: Bool = true {
        didSet { autoSave() }
    }
    
    private let userDefaults = UserDefaults.standard
    private var isLoading = false
    
    // Hardcoded Gemini API key - in production, you might want to obfuscate this
    static let geminiAPIKey = "AIzaSyBEmD7ZXT3aZGU8Eix6UhsbT5sBXfRt8F0"
    
    private enum Keys {
        static let launchAtStartup = "launchAtStartup"
        static let autoUpdates = "autoUpdates"
    }
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        isLoading = true
        launchAtStartup = userDefaults.object(forKey: Keys.launchAtStartup) as? Bool ?? true
        autoUpdates = userDefaults.object(forKey: Keys.autoUpdates) as? Bool ?? true
        isLoading = false
    }
    
    private func autoSave() {
        guard !isLoading else { return }
        userDefaults.set(launchAtStartup, forKey: Keys.launchAtStartup)
        userDefaults.set(autoUpdates, forKey: Keys.autoUpdates)
        updateLaunchAtStartupStatus()
    }
    
    func getCurrentAPIKey() -> String {
        return SettingsManager.geminiAPIKey
    }
    
    func hasValidAPIKey() -> Bool {
        return true // Always true since we have a hardcoded API key
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

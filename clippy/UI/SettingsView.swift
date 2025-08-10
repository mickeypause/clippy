import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showingAPIKeyHelp = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            providerSelection
            apiKeySection
            appSettingsSection
            usageInstructions
            
            Spacer()
            
            HStack {
                testButton
                Spacer()
                saveButton
            }
        }
        .padding(24)
        .frame(width: 480, height: 380)
        .sheet(isPresented: $showingAPIKeyHelp) {
            APIKeyHelpView()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 32))
                .foregroundColor(.accentColor)
            
            Text("Clippy Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure your AI provider to transform text anywhere on your Mac")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var providerSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Provider")
                .font(.headline)
            
            Picker("Provider", selection: $settingsManager.selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("API Key")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAPIKeyHelp = true }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("How to get API keys")
            }
            
            apiKeyInput
        }
    }
    
    @ViewBuilder
    private var apiKeyInput: some View {
        switch settingsManager.selectedProvider {
        case .openai:
            SecureField("Enter OpenAI API Key", text: $settingsManager.openAIKey)
                .textFieldStyle(.roundedBorder)
        case .gemini:
            SecureField("Enter Gemini API Key", text: $settingsManager.geminiKey)
                .textFieldStyle(.roundedBorder)
        case .claude:
            SecureField("Enter Claude API Key", text: $settingsManager.claudeKey)
                .textFieldStyle(.roundedBorder)
        }
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Settings")
                .font(.headline)
            
            Toggle("Launch Clippy at startup", isOn: $settingsManager.launchAtStartup)
                .toggleStyle(.checkbox)
        }
    }
    
    private var usageInstructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usage")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("1.")
                        .fontWeight(.medium)
                    Text("Select text anywhere on your Mac")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("2.")
                        .fontWeight(.medium)
                    Text("Press ⌘⇧T to open the transformation menu")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("3.")
                        .fontWeight(.medium)
                    Text("Choose your desired transformation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    private var testButton: some View {
        Button("Test API Connection") {
            testAPIConnection()
        }
        .disabled(!settingsManager.hasValidAPIKey())
    }
    
    private var saveButton: some View {
        Button("Save Settings") {
            settingsManager.saveSettings()
            
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Clippy Settings" }) {
                window.close()
            }
        }
        .buttonStyle(.borderedProminent)
    }
    
    private func testAPIConnection() {
        guard let apiKey = settingsManager.getCurrentAPIKey() else { return }
        
        let testService = APIServiceManager(settingsManager: settingsManager)
        
        testService.transformText("Hello world", instruction: "Make this text uppercase") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    showAlert(title: "Success", message: "API connection is working correctly!")
                case .failure(let error):
                    showAlert(title: "Connection Failed", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = title == "Success" ? .informational : .warning
        alert.runModal()
    }
}

struct APIKeyHelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("How to Get API Keys")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Close") { dismiss() }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                providerInfo("OpenAI", url: "https://platform.openai.com/api-keys", steps: [
                    "Create an account at OpenAI",
                    "Navigate to API Keys section",
                    "Click 'Create new secret key'",
                    "Copy the key (starts with 'sk-')"
                ])
                
                Divider()
                
                providerInfo("Google Gemini", url: "https://aistudio.google.com/app/apikey", steps: [
                    "Go to Google AI Studio",
                    "Sign in with your Google account",
                    "Click 'Get API key'",
                    "Copy the key (starts with 'AIza')"
                ])
                
                Divider()
                
                providerInfo("Anthropic Claude", url: "https://console.anthropic.com/", steps: [
                    "Create an account at Anthropic Console",
                    "Navigate to API Keys",
                    "Generate a new key",
                    "Copy the key (starts with 'sk-ant-')"
                ])
            }
            
            Spacer()
        }
        .padding(24)
        .frame(width: 500, height: 400)
    }
    
    private func providerInfo(_ name: String, url: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.headline)
                
                Spacer()
                
                Button("Open Website") {
                    if let url = URL(string: url) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 8)
        }
    }
}

#Preview {
    SettingsView(settingsManager: SettingsManager())
}
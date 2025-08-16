import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showingAPIKeyHelp = false
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case account = "Account"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .account: return "person.circle"
            case .about: return "info.circle"
            }
        }
        
        var title: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                // Tab bar with square icons
                tabBar
                
                // Content area
                contentArea
                
                Spacer()
                
                // Bottom action buttons
                bottomActionBar
            }
        }
        .frame(width: 700, height: 550)
        .background(.clear)
        .sheet(isPresented: $showingAPIKeyHelp) {
            APIKeyHelpView()
        }
    }
    
    
    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                        
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                    }
                    .frame(width: 64, height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                selectedTab == tab 
                                    ? Color.accentColor
                                    : Color.white.opacity(0.1)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 32)
    }
    
    private var contentArea: some View {
        ScrollView {
            VStack(spacing: 0) {
                switch selectedTab {
                case .general:
                    GeneralTabContent(settingsManager: settingsManager)
                case .account:
                    AccountTabContent(settingsManager: settingsManager, showingAPIKeyHelp: $showingAPIKeyHelp)
                case .about:
                    AboutTabContent()
                }
            }
        }
        .background(Color.clear)
    }
    
    private var bottomActionBar: some View {
        HStack {
            if selectedTab == .account {
                testButton
            }
            
            Spacer()
            
            saveButton
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .background(.ultraThinMaterial)
        )
    }
    
    private var testButton: some View {
        Button("Test API Connection") {
            testAPIConnection()
        }
        .buttonStyle(GlassmorphicButtonStyle())
        .disabled(!settingsManager.hasValidAPIKey())
    }
    
    private var saveButton: some View {
        Button("Save Settings") {
            settingsManager.saveSettings()
            
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Clippy Settings" }) {
                window.close()
            }
        }
        .buttonStyle(GlassmorphicButtonStyle(isPrimary: true))
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
    
    
// Tab Content Views
struct GeneralTabContent: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 32) {
            appSettingsSection
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Settings")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle("Launch Clippy at startup", isOn: $settingsManager.launchAtStartup)
                        .toggleStyle(.checkbox)
                    Spacer()
                }
                .padding(.vertical, 8)
                
                Text("Automatically start Clippy when you log in to your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct AccountTabContent: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var showingAPIKeyHelp: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            apiKeySection
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }
    
    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("API Configuration")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { showingAPIKeyHelp = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                        Text("Help")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
            
            Text("Enter your API key for the selected provider")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            apiKeyInput
        }
    }
    
    @ViewBuilder
    private var apiKeyInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch settingsManager.selectedProvider {
            case .openai:
                VStack(alignment: .leading, spacing: 8) {
                    Text("OpenAI API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    SecureField("sk-...", text: $settingsManager.openAIKey)
                        .textFieldStyle(GlassmorphicTextFieldStyle())
                }
            case .gemini:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google Gemini API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    SecureField("AIza...", text: $settingsManager.geminiKey)
                        .textFieldStyle(GlassmorphicTextFieldStyle())
                }
            case .claude:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Anthropic Claude API Key")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    SecureField("sk-ant-...", text: $settingsManager.claudeKey)
                        .textFieldStyle(GlassmorphicTextFieldStyle())
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct GlassmorphicTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(.primary)
    }
}

struct GlassmorphicButtonStyle: ButtonStyle {
    let isPrimary: Bool
    
    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isPrimary 
                            ? Color.accentColor
                            : Color.white.opacity(0.1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isPrimary 
                                    ? Color.clear
                                    : Color.white.opacity(0.2), 
                                lineWidth: 1
                            )
                    )
            )
            .foregroundColor(isPrimary ? .white : .primary)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct AboutTabContent: View {
    var body: some View {
        VStack(spacing: 32) {
            appInfoSection
            usageInstructionsSection
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 24)
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About Clippy")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("Transform text anywhere on your Mac using AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var usageInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Use")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 16) {
                instructionStep(number: "1", text: "Select text anywhere on your Mac")
                instructionStep(number: "2", text: "Press ⌘⇧T to open the transformation menu")
                instructionStep(number: "3", text: "Choose your desired transformation")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private func instructionStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
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

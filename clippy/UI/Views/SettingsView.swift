import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        ZStack {
            // Glassmorphic background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // App Settings
                appSettingsSection
                
                // Usage Instructions
                usageInstructionsSection
                
                Spacer()
                
                // Version at bottom
                versionFooter
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .frame(width: 500, height: 600)
        .background(.clear)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.accentColor)
            
            Text("Clippy Settings")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.top, 8)
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Settings")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            GlassmorphicContainer(padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Launch Clippy at startup", isOn: $settingsManager.launchAtStartup)
                            .toggleStyle(.checkbox)
                        
                        Text("Automatically start Clippy when you log in to your Mac")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Automatic updates", isOn: $settingsManager.autoUpdates)
                            .toggleStyle(.checkbox)
                        
                        Text("Keep Clippy updated with the latest features and fixes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var versionFooter: some View {
        Text("Clippy v1.0.0")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
    }
    
    private var usageInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Use")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            GlassmorphicContainer(padding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)) {
                VStack(alignment: .leading, spacing: 10) {
                    InstructionStepView(number: "1", text: "Select text anywhere on your Mac")
                    InstructionStepView(number: "2", text: "Press ⌘⇧T to open the transformation menu")
                    InstructionStepView(number: "3", text: "Choose your desired transformation")
                }
            }
        }
    }
}

struct InstructionStepView: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
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

#Preview {
    SettingsView(settingsManager: SettingsManager())
}
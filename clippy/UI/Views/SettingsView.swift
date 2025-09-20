import SwiftUI

struct SettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var authenticationService: AuthenticationService
    @ObservedObject var supabaseService: SupabaseService

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Authentication Section
                authenticationSection

                // App Settings
                appSettingsSection

                // Usage Instructions
                usageInstructionsSection

                Spacer(minLength: 20)

                // Version at bottom
                versionFooter
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: 520, height: 640)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Logo icon with Apple system styling
            Image(systemName: "doc.text")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("Clippy")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("AI Writing Tool for macOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 4)
    }

    private var authenticationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)
                .foregroundColor(.primary)

            AppleCard {
                AuthenticationView(
                    authenticationService: authenticationService,
                    supabaseService: supabaseService
                )
            }
        }
    }
    
    private var appSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.primary)

            AppleCard {
                VStack(alignment: .leading, spacing: 16) {
                    AppleSettingsRow(
                        title: "Launch Clippy at startup",
                        description: "Automatically start Clippy when you log in to your Mac",
                        isOn: $settingsManager.launchAtStartup
                    )

                    Divider()

                    AppleSettingsRow(
                        title: "Automatic updates",
                        description: "Keep Clippy updated with the latest features and fixes",
                        isOn: $settingsManager.autoUpdates
                    )
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
                .font(.headline)
                .foregroundColor(.primary)

            AppleCard {
                VStack(alignment: .leading, spacing: 12) {
                    AppleInstructionStep(number: "1", text: "Select text anywhere on your Mac")
                    AppleInstructionStep(number: "2", text: "Press ⌘⇧A to open the transformation menu")
                    AppleInstructionStep(number: "3", text: "Choose your desired transformation")
                }
            }
        }
    }
}

struct AppleInstructionStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                )

            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(nil)

            Spacer()
        }
    }
}

struct AppleSettingsRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
        }
    }
}

struct AppleCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                    )
            )
    }
}

#Preview {
    SettingsView(
        settingsManager: SettingsManager(),
        authenticationService: AuthenticationService(),
        supabaseService: SupabaseService(authenticationService: AuthenticationService())
    )
}
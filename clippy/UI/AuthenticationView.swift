//
//  AuthenticationView.swift
//  clippy
//
//  Created by Claude on 20.09.2025.
//

import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var authenticationService: AuthenticationService
    @ObservedObject var supabaseService: SupabaseService
    @State private var showingPrompts = false

    var body: some View {
        VStack(spacing: 24) {
            if authenticationService.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
    }

    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)

                Text("Sign in to Clippy")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("Sign in to sync your prompts and settings across devices")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Error message
            if let error = authenticationService.authenticationError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            // Sign in button
            AppleButton(action: {
                authenticationService.signIn()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                    Text("Sign in with Web Browser")
                }
            }

            // Info text
            VStack(spacing: 4) {
                Text("This will open your web browser to complete authentication.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("You'll be redirected back to this app when complete.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
    }

    private var authenticatedView: some View {
        VStack(spacing: 20) {
            // User info
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.hierarchical)

                if let user = authenticationService.user {
                    Text("Welcome, \(user.firstName ?? "User")!")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(user.email)
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("Signed In")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }

            Spacer()

            // Sign out button
            AppleButton(action: {
                authenticationService.signOut()
            }, style: .secondary) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
            }
        }
        .sheet(isPresented: $showingPrompts) {
            PromptsManagementView(supabaseService: supabaseService)
        }
        .onAppear {
            // Load prompts when the authenticated view appears
            Task {
                await supabaseService.fetchPrompts()
            }
        }
    }
}

struct PromptsManagementView: View {
    @ObservedObject var supabaseService: SupabaseService
    @Environment(\.presentationMode) var presentationMode
    @State private var newPromptName = ""
    @State private var showingAddPrompt = false

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(supabaseService.prompts) { prompt in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prompt.name)
                                    .font(.body)
                                if let createdAt = prompt.createdAt {
                                    Text("Created: \(formatDate(createdAt))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button("Delete") {
                                Task {
                                    await supabaseService.deletePrompt(id: prompt.id)
                                }
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }

                if supabaseService.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading...")
                    }
                    .padding()
                }
            }
            .navigationTitle("Prompts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        showingAddPrompt = true
                    }
                }
            }
        }
        .alert("Add New Prompt", isPresented: $showingAddPrompt) {
            TextField("Prompt name", text: $newPromptName)
            Button("Add") {
                Task {
                    await supabaseService.createPrompt(name: newPromptName)
                    newPromptName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newPromptName = ""
            }
        }
        .onAppear {
            Task {
                await supabaseService.fetchPrompts()
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

enum AppleButtonStyle {
    case primary
    case secondary
}

struct AppleButton<Content: View>: View {
    let action: () -> Void
    let style: AppleButtonStyle
    let content: Content

    init(action: @escaping () -> Void, style: AppleButtonStyle = .primary, @ViewBuilder content: () -> Content) {
        self.action = action
        self.style = style
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return .accentColor
        case .secondary:
            return Color(NSColor.controlBackgroundColor)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .accentColor
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return .clear
        case .secondary:
            return Color(NSColor.separatorColor)
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .primary:
            return 0
        case .secondary:
            return 0.5
        }
    }
}

#Preview {
    AuthenticationView(
        authenticationService: AuthenticationService(),
        supabaseService: SupabaseService(authenticationService: AuthenticationService())
    )
}
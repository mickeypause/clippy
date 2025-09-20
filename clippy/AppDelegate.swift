import AppKit
import SwiftUI
import ApplicationServices
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var globalShortcutManager: GlobalShortcutManager?
    private var textSelectionMonitor: TextSelectionMonitor?
    private var menuManager: MenuManager?
    private var textReplacer: TextReplacer?
    private var settingsManager: SettingsManager?
    private var proxyService: ProxyService?
    private var authenticationService: AuthenticationService?
    private var supabaseService: SupabaseService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarApp()
        setupDependencies()
        requestPermissions()
        setupURLHandler()
    }
    
    private func setupMenuBarApp() {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use a system image as fallback if custom icon doesn't exist
            button.image = NSImage(named: "status-bar-icon") ?? NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Clippy")
            button.action = #selector(statusItemTapped)
            button.target = self
        }

        // Initial title update
        updateStatusItemTitle()
    }
    
    private func setupDependencies() {
        settingsManager = SettingsManager()
        authenticationService = AuthenticationService()
        proxyService = ProxyService(authenticationService: authenticationService!)
        supabaseService = SupabaseService(authenticationService: authenticationService!)
        textSelectionMonitor = TextSelectionMonitor()
        textReplacer = TextReplacer()
        menuManager = MenuManager(proxyService: proxyService!)

        globalShortcutManager = GlobalShortcutManager { [weak self] in
            self?.handleGlobalShortcut()
        }

        // Observe authentication changes to update menu bar
        authenticationService?.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.updateStatusItemTitle()
            }
        }.store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
    
    private func requestPermissions() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ]
        
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showPermissionAlert()
            }
        }
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "Clippy needs accessibility permission to read and modify text across applications. Please enable it in System Preferences > Security & Privacy > Privacy > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    @objc private func statusItemTapped() {
        showSettingsWindow()
    }
    
    private func showSettingsWindow() {
        let settingsView = SettingsView(
            settingsManager: settingsManager!,
            authenticationService: authenticationService!,
            supabaseService: supabaseService!
        )
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Clippy"
        window.setContentSize(NSSize(width: 500, height: 600))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func handleGlobalShortcut() {
        do {
            guard AXIsProcessTrusted() else {
                showPermissionAlert()
                return
            }
            
            guard let textSelectionMonitor = textSelectionMonitor,
                  let menuManager = menuManager,
                  let textReplacer = textReplacer else {
                print("Error: Core components not initialized")
                return
            }
            
            // Small delay to ensure text selection is stable
            Thread.sleep(forTimeInterval: 0.05)
            
            let selectedText = textSelectionMonitor.getSelectedText()
            let selectionBounds = textSelectionMonitor.getSelectionBounds()
            
            print("Selected text: '\(selectedText)'")
            print("Selection bounds: \(selectionBounds)")
            
            guard !selectedText.isEmpty else {
                showNoTextSelectedAlert()
                return
            }
            
            // Check authentication before showing menu to prevent flash
            guard authenticationService?.isAuthenticated == true else {
                showAuthRequiredAlert()
                return
            }
            
            menuManager.showContextMenu(
                at: selectionBounds,
                selectedText: selectedText
            ) { [weak self] transformedText in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    do {
                        let success = textReplacer.replaceSelectedText(with: transformedText)
                        print("Text replacement \(success ? "succeeded" : "failed")")
                    } catch {
                        print("Error replacing text: \(error)")
                    }
                }
            }
        } catch {
            print("Error in handleGlobalShortcut: \(error)")
            showErrorAlert("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
    
    private func showErrorAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func showNoTextSelectedAlert() {
        let alert = NSAlert()
        alert.messageText = "No Text Selected"
        alert.informativeText = "Please select some text first, then use the keyboard shortcut."
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    private func showAuthRequiredAlert() {
        let alert = NSAlert()
        alert.messageText = "Authentication Required"
        alert.informativeText = "Please sign in to use AI transformations."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showSettingsWindow()
        }
    }

    // MARK: - URL Scheme Handling

    private func setupURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        handleAuthenticationURL(url)
    }

    private func handleAuthenticationURL(_ url: URL) {
        guard url.scheme == "clippyapp" else {
            print("Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }

        authenticationService?.handleAuthenticationCallback(url: url)

        // Update status item after authentication
        DispatchQueue.main.async {
            self.updateStatusItemTitle()
        }
    }

    // MARK: - Public Access Methods

    func getAuthenticationService() -> AuthenticationService? {
        return authenticationService
    }

    func getSupabaseService() -> SupabaseService? {
        return supabaseService
    }

    // MARK: - Status Item Updates

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }

        if let authService = authenticationService,
           authService.isAuthenticated,
           let user = authService.user {
            // Show user name when authenticated
            let displayName = user.firstName ?? user.email.components(separatedBy: "@").first ?? "User"
            button.title = " \(displayName)"
            button.toolTip = "Clippy - Signed in as \(user.email)"
        } else {
            // Show default when not authenticated
            button.title = ""
            button.toolTip = "Clippy - Click to open settings"
        }
    }
}

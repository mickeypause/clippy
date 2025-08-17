import AppKit
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var globalShortcutManager: GlobalShortcutManager?
    private var textSelectionMonitor: TextSelectionMonitor?
    private var menuManager: MenuManager?
    private var textReplacer: TextReplacer?
    private var settingsManager: SettingsManager?
    private var apiServiceManager: APIServiceManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarApp()
        setupDependencies()
        requestPermissions()
    }
    
    private func setupMenuBarApp() {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(named: "status-bar-icon")
            button.action = #selector(statusItemTapped)
            button.target = self
        }
    }
    
    private func setupDependencies() {
        settingsManager = SettingsManager()
        apiServiceManager = APIServiceManager()
        textSelectionMonitor = TextSelectionMonitor()
        textReplacer = TextReplacer()
        menuManager = MenuManager(apiService: apiServiceManager!)
        
        globalShortcutManager = GlobalShortcutManager { [weak self] in
            self?.handleGlobalShortcut()
        }
    }
    
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
        let settingsView = SettingsView(settingsManager: settingsManager!)
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
            
            // Check API key before showing menu to prevent flash
            guard apiServiceManager?.hasValidAPIKey() == true else {
                showAPIKeyAlert()
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
    
    private func showAPIKeyAlert() {
        let alert = NSAlert()
        alert.messageText = "API Key Required"
        alert.informativeText = "Please configure your AI provider in the settings first."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            showSettingsWindow()
        }
    }
}

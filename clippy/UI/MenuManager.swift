import AppKit

final class MenuManager: NSObject {
    private let proxyService: ProxyService
    private var activeWindow: NSWindow?
    private let tooltipController = TooltipViewController()
    private let systemLevelReplacer = SystemLevelTextReplacer()

    init(proxyService: ProxyService) {
        self.proxyService = proxyService
        super.init()
    }
    
    func showContextMenu(
        at bounds: CGRect,
        selectedText: String,
        completion: @escaping (String) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.displayMenu(at: bounds, selectedText: selectedText, completion: completion)
        }
    }
    
    private func displayMenu(
        at bounds: CGRect,
        selectedText: String,
        completion: @escaping (String) -> Void
    ) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        addAIMenuItems(to: menu, selectedText: selectedText, selectionBounds: bounds, completion: completion)
        
        // Get the screen that contains the selected text
        let screenWithText = getScreenContaining(point: bounds.origin)
        
        // Calculate center of that screen
        let centerPoint = getCenterPoint(for: screenWithText)
        
        displayMenuAtLocation(menu: menu, at: centerPoint)
    }
    
   
    
    private func addAIMenuItems(
        to menu: NSMenu,
        selectedText: String,
        selectionBounds: CGRect,
        completion: @escaping (String) -> Void
    ) {
        // API key validation is now handled in AppDelegate before menu creation
        
        let aiTransformations = [
            ("🔧 Fix Grammar", "Fix any grammar, spelling, and punctuation errors in this text"),
            ("🎯 Make Professional", "Rewrite this text in a professional tone suitable for business communication"),
            ("✂️ Make Shorter", "Rewrite this text to be more concise while preserving all important information")
        ]
        
        for (title, instruction) in aiTransformations {
            let item = NSMenuItem(title: title, action: #selector(handleAITransformation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = AITransformationAction(
                instruction: instruction,
                selectedText: selectedText,
                selectionBounds: selectionBounds,
                completion: completion
            )
            item.isEnabled = true
            menu.addItem(item)
        }
    }
    
    private func displayMenuAtLocation(menu: NSMenu, at point: NSPoint) {
        closeActiveWindow()
        
        menu.delegate = self
        
        // No additional async call - we're already on main queue from showContextMenu
        menu.popUp(positioning: nil, at: point, in: nil)
    }
    
    private func getScreenContaining(point: CGPoint) -> NSScreen {
        // Find the screen that contains the selected text
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        // Fallback to main screen if point is not found on any screen
        return NSScreen.main ?? NSScreen.screens.first!
    }
    
    private func getCenterPoint(for screen: NSScreen) -> NSPoint {
        let frame = screen.visibleFrame
        return NSPoint(
            x: frame.midX,
            y: frame.midY
        )
    }
    
    @objc private func handleTransformation(_ sender: NSMenuItem) {
        print("🔧 Handling transformation: \(sender.title)")
        
        guard let action = sender.representedObject as? TransformationAction else {
            print("❌ No action found for transformation")
            return
        }
        
        let result = action.transform()
        print("✅ Transformation result: '\(result)'")
        action.completion(result)
        closeActiveWindow()
    }
    
    @objc private func handleAITransformation(_ sender: NSMenuItem) {
        print("🤖 Handling AI transformation: \(sender.title)")
        
        guard let action = sender.representedObject as? AITransformationAction else {
            print("❌ No AI action found for transformation")
            return
        }
        
        closeActiveWindow()

        print("📡 Sending request to proxy...")

        proxyService.transformText(action.selectedText, instruction: action.instruction) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transformedText):
                    print("✅ Proxy transformation successful: '\(transformedText)'")

                    // Try system-level replacement first (works universally)
                    if self?.systemLevelReplacer.replaceSelectedTextUniversally(with: transformedText) == true {
                        print("✅ System-level text replacement succeeded")
                    } else {
                        print("❌ System-level replacement failed, using callback")
                        action.completion(transformedText)
                    }
                case .failure(let error):
                    print("❌ Proxy transformation failed: \(error)")
                    self?.showProxyErrorAlert(error)
                }
            }
        }
    }
    
    private func closeActiveWindow() {
        activeWindow?.close()
        activeWindow = nil
    }
    
    private func showProxyErrorAlert(_ error: ProxyError) {
        let alert = NSAlert()
        alert.messageText = "Transformation Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension MenuManager: NSMenuDelegate {
    func menuDidClose(_ menu: NSMenu) {
        DispatchQueue.main.async { [weak self] in
            self?.closeActiveWindow()
        }
    }
}

private struct TransformationAction {
    let transform: () -> String
    let completion: (String) -> Void
}

private struct AITransformationAction {
    let instruction: String
    let selectedText: String
    let selectionBounds: CGRect
    let completion: (String) -> Void
}

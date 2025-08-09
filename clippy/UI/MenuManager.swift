import AppKit

final class MenuManager: NSObject {
    private let apiService: APIServiceManager
    private var activeWindow: NSWindow?
    private let tooltipController = TooltipViewController()
    
    init(apiService: APIServiceManager) {
        self.apiService = apiService
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
        
        addTransformationMenuItems(to: menu, selectedText: selectedText, completion: completion)
        menu.addItem(NSMenuItem.separator())
        addAIMenuItems(to: menu, selectedText: selectedText, selectionBounds: bounds, completion: completion)
        
        let menuPosition = CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y - 20,
            width: max(bounds.width, 200),
            height: 20
        )
        
        displayMenuAtLocation(menu: menu, bounds: menuPosition)
    }
    
    private func addTransformationMenuItems(
        to menu: NSMenu,
        selectedText: String,
        completion: @escaping (String) -> Void
    ) {
        let transformations: [(String, (String) -> String)] = [
            ("UPPERCASE", { $0.uppercased() }),
            ("lowercase", { $0.lowercased() }),
            ("Title Case", { $0.capitalized }),
            ("Reverse Text", { String($0.reversed()) }),
            ("Character Count", { "\($0.count) characters" }),
            ("Word Count", { "\($0.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count) words" }),
            ("Remove Extra Spaces", { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) })
        ]
        
        for (title, transform) in transformations {
            let item = NSMenuItem(title: title, action: #selector(handleTransformation(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = TransformationAction(
                transform: { transform(selectedText) },
                completion: completion
            )
            item.isEnabled = true
            menu.addItem(item)
        }
    }
    
    private func addAIMenuItems(
        to menu: NSMenu,
        selectedText: String,
        selectionBounds: CGRect,
        completion: @escaping (String) -> Void
    ) {
        guard apiService.hasValidAPIKey() else {
            let item = NSMenuItem(title: "Configure AI Provider First...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return
        }
        
        let aiTransformations = [
            ("✨ Improve Writing", "Improve the writing quality, grammar, and clarity of this text while maintaining its original meaning"),
            ("📝 Summarize", "Create a concise summary of this text, highlighting the main points"),
            ("✂️ Make Shorter", "Rewrite this text to be more concise while preserving all important information"),
            ("🔧 Fix Grammar", "Fix any grammar, spelling, and punctuation errors in this text"),
            ("🎯 Make Professional", "Rewrite this text in a professional tone suitable for business communication"),
            ("😊 Make Casual", "Rewrite this text in a casual, friendly tone"),
            ("🔍 Explain", "Explain what this text means in simple, easy-to-understand language"),
            ("🌍 Translate", "Detect the language and translate this text to English (or to the most appropriate language)")
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
    
    private func displayMenuAtLocation(menu: NSMenu, bounds: CGRect) {
        closeActiveWindow()
        
        menu.delegate = self
        
        DispatchQueue.main.async {
            let screenPoint = NSPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.height)
            menu.popUp(positioning: nil, at: screenPoint, in: nil)
        }
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
        
        // Show tooltip with loading state
        tooltipController.showTooltip(
            at: action.selectionBounds,
            originalText: action.selectedText
        ) { [weak self] transformedText in
            // This closure is called when user accepts the transformation
            DispatchQueue.main.async {
                action.completion(transformedText)
                self?.tooltipController.hideTooltip()
            }
        }
        
        print("📡 Sending request to API...")
        
        apiService.transformText(action.selectedText, instruction: action.instruction) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transformedText):
                    print("✅ AI transformation successful: '\(transformedText)'")
                    self?.tooltipController.updateWithResult(transformedText)
                case .failure(let error):
                    print("❌ AI transformation failed: \(error)")
                    self?.tooltipController.hideTooltip()
                    self?.showErrorAlert(error)
                }
            }
        }
    }
    
    private func closeActiveWindow() {
        activeWindow?.close()
        activeWindow = nil
    }
    
    private func showErrorAlert(_ error: APIError) {
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
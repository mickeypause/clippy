import ApplicationServices
import AppKit
import Carbon
import CoreGraphics

final class TextReplacer {
    private var originalPasteboardContents = NSMutableArray()
    
    private func isSecureInputEnabled() -> Bool {
        return IsSecureEventInputEnabled()
    }
    
    func replaceSelectedText(with newText: String) -> Bool {
        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return false
        }
        
        // Check for secure input which blocks keyboard simulation
        if isSecureInputEnabled() {
            print("⚠️ Secure input is enabled - keyboard simulation will be blocked")
        }
        
        // Universal approach: try methods in order from most specific to most compatible
        
        print("🔄 Attempting direct accessibility replacement...")
        if tryDirectReplacement(newText) {
            print("✅ Direct replacement succeeded")
            return true
        }
        print("❌ Direct replacement failed")
        
        // Try clipboard method first as it's more likely to work with secure input
        print("🔄 Attempting enhanced clipboard method...")
        if tryEnhancedClipboardMethod(newText) {
            print("✅ Enhanced clipboard method completed")
            return true
        }
        print("❌ Enhanced clipboard method failed")
        
        // Only try keyboard simulation if secure input is disabled
        if !isSecureInputEnabled() {
            print("🔄 Attempting keyboard simulation (character by character)...")
            if tryKeyboardSimulation(newText) {
                print("✅ Keyboard simulation completed")
                return true
            }
            print("❌ Keyboard simulation failed")
        } else {
            print("⚠️ Skipping keyboard simulation due to secure input")
        }
        
        // Final fallback: try paste without selection
        print("🔄 Attempting direct paste fallback...")
        if tryDirectPasteFallback(newText) {
            print("✅ Direct paste fallback completed")
            return true
        }
        print("❌ Direct paste fallback failed")
        
        print("❌ All replacement methods failed")
        showFallbackAlert(newText)
        return false
    }
    
    private func tryEnhancedClipboardMethod(_ newText: String) -> Bool {
        backupClipboard()
        
        // Try multiple selection methods
        let selectionMethods = [
            { self.simulateSelectAll() },
            { self.simulateTripleClick() },
            { self.simulateDoubleClickAndDrag() }
        ]
        
        for (index, method) in selectionMethods.enumerated() {
            print("🔄 Trying selection method \(index + 1)...")
            
            if method() {
                usleep(200000) // Longer delay for selection
                
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(newText, forType: .string)
                
                usleep(300000) // Even longer delay for clipboard
                
                if simulatePaste() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.restoreClipboard()
                    }
                    return true
                }
            }
        }
        
        restoreClipboard()
        return false
    }
    
    private func tryDirectPasteFallback(_ newText: String) -> Bool {
        backupClipboard()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        usleep(300000)
        
        let success = simulatePaste()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.restoreClipboard()
        }
        
        return success
    }
    
    private func simulateTripleClick() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Get current mouse location
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 1000
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)
        
        // Triple click at current location
        let tripleClick = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: cgPoint, mouseButton: .left)
        tripleClick?.setIntegerValueField(.mouseEventClickState, value: 3)
        tripleClick?.post(tap: .cghidEventTap)
        
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: cgPoint, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func simulateDoubleClickAndDrag() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Get current mouse location
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 1000
        let startPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)
        let endPoint = CGPoint(x: currentLocation.x + 200, y: screenHeight - currentLocation.y)
        
        // Double click
        let doubleClick = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
        doubleClick?.setIntegerValueField(.mouseEventClickState, value: 2)
        doubleClick?.post(tap: .cghidEventTap)
        
        usleep(10000)
        
        let mouseUp1 = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: startPoint, mouseButton: .left)
        mouseUp1?.post(tap: .cghidEventTap)
        
        usleep(50000)
        
        // Drag to select more text
        let dragStart = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
        dragStart?.post(tap: .cghidEventTap)
        
        let drag = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: endPoint, mouseButton: .left)
        drag?.post(tap: .cghidEventTap)
        
        let dragEnd = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left)
        dragEnd?.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func tryDirectReplacement(_ newText: String) -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, 
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return false
        }
        
        let axElement = element as! AXUIElement
        
        // Try different methods based on element type and application
        if tryWebKitReplacement(axElement, newText: newText) {
            return true
        }
        
        if tryStandardReplacement(axElement, newText: newText) {
            return true
        }
        
        if tryValueReplacement(axElement, newText: newText) {
            return true
        }
        
        if trySelectedTextRangeReplacement(axElement, newText: newText) {
            return true
        }
        
        return false
    }
    
    private func tryKeyboardSimulation(_ newText: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        usleep(100000) // Initial delay
        
        // First select all existing text with Cmd+A
        if !simulateSelectAll() {
            return false
        }
        
        usleep(150000) // Longer delay for selection to take effect across all apps
        
        return typeTextCharacterByCharacter(newText, source: source)
    }
    
    private func tryClipboardMethod(_ newText: String) -> Bool {
        backupClipboard()
        
        // First select all existing text with Cmd+A
        if !simulateSelectAll() {
            restoreClipboard()
            return false
        }
        
        usleep(150000) // Universal delay for selection across all apps
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        usleep(250000) // Longer delay to ensure clipboard is ready for all apps
        
        let success = simulatePaste()
        
        // Restore clipboard after a longer delay to ensure paste completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.restoreClipboard()
        }
        
        return success
    }
    
    private func typeText(_ text: String, source: CGEventSource?) -> Bool {
        guard let keyboardEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
            return false
        }
        
        let utf16Array = Array(text.utf16)
        keyboardEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
        keyboardEvent.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func typeTextCharacterByCharacter(_ text: String, source: CGEventSource?) -> Bool {
        // Type each character individually - works universally across all apps
        for char in text {
            let charString = String(char)
            let utf16Array = Array(charString.utf16)
            
            guard let keyboardEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                return false
            }
            
            keyboardEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
            keyboardEvent.post(tap: .cghidEventTap)
            
            // Adaptive delay: slightly longer for special characters
            let delay: useconds_t = char.isWhitespace || char.isPunctuation ? 2000 : 1500
            usleep(delay)
        }
        
        return true
    }
    
    private func tryWebFormReplacement(_ newText: String) -> Bool {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        
        // Check if we're in a web browser
        let browserBundleIds = ["com.google.Chrome", "com.apple.Safari", "org.mozilla.firefox", "com.microsoft.edgemac"]
        guard browserBundleIds.contains(frontmostApp.bundleIdentifier ?? "") else {
            return false
        }
        
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Try triple-click to select all text in the current field/paragraph
        let tripleClick = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)
        tripleClick?.setIntegerValueField(.mouseEventClickState, value: 3)
        tripleClick?.post(tap: .cghidEventTap)
        
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
        
        usleep(100000)
        
        // Now type the replacement text
        return typeText(newText, source: source)
    }
    
    private func simulateSelectAll() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd+A to select all
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) // 'A' key
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        
        keyDownEvent?.post(tap: .cghidEventTap)
        usleep(10000)
        keyUpEvent?.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func simulatePaste() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        
        keyDownEvent?.flags = .maskCommand
        keyUpEvent?.flags = .maskCommand
        
        keyDownEvent?.post(tap: .cghidEventTap)
        usleep(10000)
        keyUpEvent?.post(tap: .cghidEventTap)
        
        return true
    }
    
    private func backupClipboard() {
        let pasteboard = NSPasteboard.general
        originalPasteboardContents.removeAllObjects()
        
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                originalPasteboardContents.add([type.rawValue: data])
            }
        }
    }
    
    private func restoreClipboard() {
        guard originalPasteboardContents.count > 0 else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var itemsToRestore: [(NSPasteboard.PasteboardType, Data)] = []
        
        for item in originalPasteboardContents {
            if let dict = item as? [String: Data],
               let (typeString, data) = dict.first {
                let type = NSPasteboard.PasteboardType(typeString)
                itemsToRestore.append((type, data))
            }
        }
        
        for (type, data) in itemsToRestore {
            pasteboard.setData(data, forType: type)
        }
        
        originalPasteboardContents.removeAllObjects()
    }
    
    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "Clippy needs accessibility permission to modify text. Please enable it in System Preferences > Security & Privacy > Privacy > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Preferences")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func tryWebKitReplacement(_ element: AXUIElement, newText: String) -> Bool {
        // For WebKit applications (Safari, Chrome, etc.), try AXTextMarker approach
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &selectedRange)
        
        if rangeResult == .success, selectedRange != nil {
            // Try to set the attributed string for the text marker range
            let setResult = AXUIElementSetAttributeValue(element, "AXAttributedStringForTextMarkerRange" as CFString, newText as CFString)
            if setResult == .success {
                return true
            }
        }
        
        return false
    }
    
    private func tryStandardReplacement(_ element: AXUIElement, newText: String) -> Bool {
        // Try standard selected text replacement
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFString)
        return status == .success
    }
    
    private func tryValueReplacement(_ element: AXUIElement, newText: String) -> Bool {
        // Try replacing the entire value (for text fields)
        let status = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFString)
        return status == .success
    }
    
    private func trySelectedTextRangeReplacement(_ element: AXUIElement, newText: String) -> Bool {
        // Get the selected text range first
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        if rangeResult == .success, let range = selectedRange {
            // Try to get the current text
            var currentValue: CFTypeRef?
            let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
            
            if valueResult == .success, let currentText = currentValue as? String {
                // Extract range information
                let rangeValue = range as! AXValue
                var cfRange = CFRange(location: 0, length: 0)
                let success = AXValueGetValue(rangeValue, .cfRange, &cfRange)
                
                if success {
                    // Replace the text at the specific range
                    let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
                    var newFullText = currentText
                    
                    if nsRange.location != NSNotFound && nsRange.location + nsRange.length <= currentText.count {
                        let startIndex = currentText.index(currentText.startIndex, offsetBy: nsRange.location)
                        let endIndex = currentText.index(startIndex, offsetBy: nsRange.length)
                        newFullText.replaceSubrange(startIndex..<endIndex, with: newText)
                        
                        // Set the new full text
                        let setResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newFullText as CFString)
                        return setResult == .success
                    }
                }
            }
        }
        
        return false
    }
    
    private func showFallbackAlert(_ newText: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Text Replacement Failed"
            alert.informativeText = "Unable to replace the selected text automatically. The transformed text has been copied to your clipboard."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(newText, forType: .string)
            
            alert.runModal()
        }
    }
}
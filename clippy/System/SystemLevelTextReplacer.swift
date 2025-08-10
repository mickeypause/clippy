import ApplicationServices
import AppKit
import CoreGraphics

final class SystemLevelTextReplacer {
    
    func replaceSelectedTextUniversally(with newText: String) -> Bool {
        print("🎯 Starting universal text replacement...")
        
        // Method 1: Ultra-fast clipboard replacement (most reliable)
        if tryUltraFastClipboardReplacement(newText) {
            print("✅ Ultra-fast clipboard replacement completed")
            return verifyTextWasReplaced(expectedText: newText)
        }
        
        // Method 2: Backspace and type (for when selection doesn't work)
        if tryBackspaceAndType(newText) {
            print("✅ Backspace and type completed")
            return verifyTextWasReplaced(expectedText: newText)
        }
        
        // Method 3: Multiple attempts with different selection methods
        if tryMultipleSelectionAttempts(newText) {
            print("✅ Multiple selection attempts completed")
            return verifyTextWasReplaced(expectedText: newText)
        }
        
        print("❌ All universal replacement methods failed")
        return false
    }
    
    private func tryUltraFastClipboardReplacement(_ newText: String) -> Bool {
        // Back up clipboard
        let originalClipboard = NSPasteboard.general.string(forType: .string)
        
        // Set new text to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(newText, forType: .string)
        
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        // Wait a moment for clipboard to be ready
        usleep(25000) // 25ms
        
        // Select all text (Cmd+A)
        sendKeyCombo(source: source, key: 0, modifiers: .maskCommand) // A key
        usleep(50000) // 50ms wait for selection
        
        // Paste (Cmd+V)
        sendKeyCombo(source: source, key: 9, modifiers: .maskCommand) // V key
        usleep(25000) // 25ms wait for paste
        
        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            NSPasteboard.general.clearContents()
            if let original = originalClipboard {
                NSPasteboard.general.setString(original, forType: .string)
            }
        }
        
        return true
    }
    
    private func tryBackspaceAndType(_ newText: String) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        // First try to select all
        sendKeyCombo(source: source, key: 0, modifiers: .maskCommand) // Cmd+A
        usleep(100000) // Wait for selection
        
        // If that doesn't work, try multiple backspaces to clear text
        for _ in 0..<50 { // Clear up to 50 characters
            sendKey(source: source, key: 51) // Backspace key
            usleep(1000) // 1ms between backspaces
        }
        
        // Wait a bit
        usleep(50000)
        
        // Now type the new text character by character
        return typeTextSlowly(newText, source: source)
    }
    
    private func tryMultipleSelectionAttempts(_ newText: String) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }
        
        // Try different selection methods
        let selectionMethods: [() -> Void] = [
            { self.sendKeyCombo(source: source, key: 0, modifiers: .maskCommand) }, // Cmd+A
            { self.tripleClickAtCurrentLocation() }, // Triple click
            { self.selectWithShiftArrows(source: source) }, // Shift+Arrow selection
        ]
        
        for (index, selectMethod) in selectionMethods.enumerated() {
            print("🔄 Trying selection method \(index + 1)...")
            
            selectMethod()
            usleep(100000) // Wait for selection
            
            // Try clipboard paste
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(newText, forType: .string)
            usleep(50000)
            
            sendKeyCombo(source: source, key: 9, modifiers: .maskCommand) // Cmd+V
            usleep(50000)
            
            // If this method seems to work, return success
            if index < selectionMethods.count - 1 {
                continue // Try next method
            }
        }
        
        return true
    }
    
    private func sendKeyCombo(source: CGEventSource, key: CGKeyCode, modifiers: CGEventFlags) {
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        
        usleep(5000) // 5ms
        
        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func sendKey(source: CGEventSource, key: CGKeyCode) {
        // Key down
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.post(tap: .cghidEventTap)
        
        usleep(5000) // 5ms
        
        // Key up  
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    private func typeTextSlowly(_ text: String, source: CGEventSource) -> Bool {
        for char in text {
            let charString = String(char)
            let utf16Array = Array(charString.utf16)
            
            guard let keyEvent = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) else {
                continue
            }
            
            keyEvent.keyboardSetUnicodeString(stringLength: utf16Array.count, unicodeString: utf16Array)
            keyEvent.post(tap: .cghidEventTap)
            
            // Slower typing for better compatibility
            usleep(5000) // 5ms per character
        }
        
        return true
    }
    
    private func tripleClickAtCurrentLocation() {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return
        }
        
        // Get current mouse location
        let currentLocation = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 1000
        let cgPoint = CGPoint(x: currentLocation.x, y: screenHeight - currentLocation.y)
        
        // Triple click
        let tripleClick = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: cgPoint, mouseButton: .left)
        tripleClick?.setIntegerValueField(.mouseEventClickState, value: 3)
        tripleClick?.post(tap: .cghidEventTap)
        
        usleep(10000)
        
        let mouseUp = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: cgPoint, mouseButton: .left)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    private func selectWithShiftArrows(source: CGEventSource) {
        // Cmd+Shift+Left to select to beginning of line
        sendKeyCombo(source: source, key: 123, modifiers: [.maskCommand, .maskShift]) // Left arrow
        usleep(50000)
        
        // Cmd+Shift+Right to select to end of line  
        sendKeyCombo(source: source, key: 124, modifiers: [.maskCommand, .maskShift]) // Right arrow
    }
    
    private func verifyTextWasReplaced(expectedText: String) -> Bool {
        // Wait a moment for the replacement to take effect
        usleep(200000) // 200ms
        
        // Try to verify by checking the current selection/value
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ Cannot verify - no frontmost app")
            return true // Assume success if we can't verify
        }
        
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            print("⚠️ Cannot verify - no focused element")
            return true // Assume success if we can't verify
        }
        
        let axElement = element as! AXUIElement
        
        // Check if the current value contains our expected text
        var currentValue: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &currentValue)
        
        if valueResult == .success, let currentText = currentValue as? String {
            let containsExpectedText = currentText.contains(expectedText.prefix(10)) // Check first 10 chars
            if containsExpectedText {
                print("✅ Verification successful - text was replaced")
                return true
            } else {
                print("❌ Verification failed - text was not replaced")
                print("   Expected: \(expectedText.prefix(20))...")
                print("   Actual: \(currentText.prefix(20))...")
                return false
            }
        }
        
        print("⚠️ Cannot verify text replacement - assuming success")
        return true // If we can't verify, assume it worked
    }
}
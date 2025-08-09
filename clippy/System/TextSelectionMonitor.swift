import ApplicationServices
import AppKit

final class TextSelectionMonitor {
    
    func getSelectedText() -> String {
        print("=== Starting text selection detection ===")
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("No frontmost application")
            return getClipboardText()
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        print("Checking app: \(appName)")
        
        // Try accessibility method first (but only if trusted)
        if AXIsProcessTrusted() {
            let accessibilityText = tryAccessibilityMethod(frontmostApp)
            if !accessibilityText.isEmpty {
                print("✅ Got text from accessibility: '\(accessibilityText)'")
                return accessibilityText
            }
        }
        
        // Always try clipboard method as fallback (works for all apps)
        print("🔄 Using universal clipboard method")
        let clipboardText = getClipboardText()
        print("Final result: '\(clipboardText)'")
        return clipboardText
    }
    
    private func tryAccessibilityMethod(_ frontmostApp: NSRunningApplication) -> String {
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        print("Accessibility focused element result: \(result)")
        
        if result == .success, 
           let element = focusedElement,
           CFGetTypeID(element) == AXUIElementGetTypeID() {
            
            return getSelectedTextFromElement(element as! AXUIElement) ?? ""
        }
        
        return ""
    }
    
    func getSelectionBounds() -> CGRect {
        guard AXIsProcessTrusted() else {
            return getScreenCenterRect()
        }
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return getScreenCenterRect()
        }
        
        let appRef = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, 
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return getScreenCenterRect()
        }
        
        if let bounds = getBoundsFromElement(element as! AXUIElement) {
            return bounds
        }
        
        return getScreenCenterRect()
    }
    
    private func getSelectedTextFromElement(_ element: AXUIElement) -> String? {
        // Try direct selected text first
        var selectedText: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText)
        
        print("Direct selected text result: \(result)")
        
        if result == .success, let text = selectedText as? String, !text.isEmpty {
            print("Found direct selected text: '\(text)'")
            return text
        }
        
        // Try getting text from value and range
        var value: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        print("Value result: \(valueResult)")
        
        if valueResult == .success, let fullText = value as? String {
            print("Full text length: \(fullText.count)")
            
            var selectedRange: CFTypeRef?
            let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
            
            print("Range result: \(rangeResult)")
            
            if rangeResult == .success,
               let range = selectedRange,
               CFGetTypeID(range) == AXValueGetTypeID() {
                
                var cfRange = CFRange()
                if AXValueGetValue(range as! AXValue, .cfRange, &cfRange) {
                    print("Selection range: location=\(cfRange.location), length=\(cfRange.length)")
                    
                    let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
                    if nsRange.location != NSNotFound && 
                       nsRange.location >= 0 &&
                       nsRange.length > 0 &&
                       nsRange.location + nsRange.length <= fullText.count {
                        
                        let startIndex = fullText.index(fullText.startIndex, offsetBy: nsRange.location)
                        let endIndex = fullText.index(startIndex, offsetBy: nsRange.length)
                        let selectedText = String(fullText[startIndex..<endIndex])
                        print("Extracted selected text: '\(selectedText)'")
                        return selectedText
                    }
                }
            }
        }
        
        print("No selected text found via accessibility")
        return nil
    }
    
    private func getBoundsFromElement(_ element: AXUIElement) -> CGRect? {
        if let directBounds = getDirectBoundsFromElement(element) {
            return convertToScreenCoordinates(directBounds)
        }
        
        if let selectionBounds = getSelectionBoundsFromElement(element) {
            return convertToScreenCoordinates(selectionBounds)
        }
        
        if let elementBounds = getElementBoundsFromElement(element) {
            return convertToScreenCoordinates(elementBounds)
        }
        
        return nil
    }
    
    private func getDirectBoundsFromElement(_ element: AXUIElement) -> CGRect? {
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        guard rangeResult == .success, let range = selectedRange else {
            return nil
        }
        
        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &boundsValue
        )
        
        guard boundsResult == .success, let bounds = boundsValue else {
            return nil
        }
        
        var rect = CGRect.zero
        if AXValueGetValue(bounds as! AXValue, .cgRect, &rect) {
            return rect
        }
        
        return nil
    }
    
    private func getSelectionBoundsFromElement(_ element: AXUIElement) -> CGRect? {
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        guard rangeResult == .success, let range = selectedRange else {
            return nil
        }
        
        var cfRange = CFRange()
        guard AXValueGetValue(range as! AXValue, .cfRange, &cfRange) else {
            return nil
        }
        
        var startRange = CFRangeMake(cfRange.location, 0)
        guard let startRangeValue = AXValueCreate(.cfRange, &startRange) else {
            return nil
        }
        
        var startBoundsValue: CFTypeRef?
        let startBoundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            startRangeValue,
            &startBoundsValue
        )
        
        guard startBoundsResult == .success, let startBounds = startBoundsValue else {
            return nil
        }
        
        var startRect = CGRect.zero
        guard AXValueGetValue(startBounds as! AXValue, .cgRect, &startRect) else {
            return nil
        }
        
        let endLocation = cfRange.location + cfRange.length
        var endRange = CFRangeMake(endLocation, 0)
        guard let endRangeValue = AXValueCreate(.cfRange, &endRange) else {
            return startRect
        }
        
        var endBoundsValue: CFTypeRef?
        let endBoundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            endRangeValue,
            &endBoundsValue
        )
        
        if endBoundsResult == .success, let endBounds = endBoundsValue {
            var endRect = CGRect.zero
            if AXValueGetValue(endBounds as! AXValue, .cgRect, &endRect) {
                return CGRect(
                    x: startRect.origin.x,
                    y: startRect.origin.y,
                    width: endRect.origin.x - startRect.origin.x + endRect.width,
                    height: max(startRect.height, endRect.height)
                )
            }
        }
        
        return startRect
    }
    
    private func getElementBoundsFromElement(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        let positionResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size)
        
        guard positionResult == .success, let pos = position,
              sizeResult == .success, let sz = size else {
            return nil
        }
        
        var point = CGPoint.zero
        var cgSize = CGSize.zero
        
        guard AXValueGetValue(pos as! AXValue, .cgPoint, &point),
              AXValueGetValue(sz as! AXValue, .cgSize, &cgSize) else {
            return nil
        }
        
        return CGRect(origin: point, size: cgSize)
    }
    
    private func convertToScreenCoordinates(_ rect: CGRect) -> CGRect {
        guard let screen = NSScreen.main else {
            return rect
        }
        
        let screenHeight = screen.frame.height
        let flippedY = screenHeight - rect.origin.y - rect.height
        
        return CGRect(
            x: rect.origin.x,
            y: flippedY,
            width: rect.width,
            height: rect.height
        )
    }
    
    private func getClipboardText() -> String {
        let originalClipboard = NSPasteboard.general.string(forType: .string)
        let originalChangeCount = NSPasteboard.general.changeCount
        print("Original clipboard: '\(originalClipboard ?? "nil")' (changeCount: \(originalChangeCount))")
        
        // Try copying selected text
        simulateCopyCommand()
        
        // Wait for copy operation to complete
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            Thread.sleep(forTimeInterval: 0.05) // Check every 50ms
            attempts += 1
            
            let currentChangeCount = NSPasteboard.general.changeCount
            
            // If clipboard change count increased, the copy worked
            if currentChangeCount > originalChangeCount {
                let newClipboard = NSPasteboard.general.string(forType: .string)
                print("Clipboard changed! New content: '\(newClipboard ?? "nil")' (attempt \(attempts))")
                
                if let newText = newClipboard, !newText.isEmpty {
                    print("✅ Successfully got text from clipboard: '\(newText)'")
                    return newText
                }
                break
            }
        }
        
        // If we get here, either copy failed or there was no selection
        print("No clipboard change detected after \(attempts) attempts")
        
        // Last resort: check if there's anything useful in the current clipboard
        let currentClipboard = NSPasteboard.general.string(forType: .string)
        if let existingText = currentClipboard, 
           !existingText.isEmpty,
           existingText.count < 1000, // Reasonable length for selected text
           !existingText.contains("\n\n\n") { // Not a large document
            print("Using existing clipboard as fallback: '\(existingText)'")
            return existingText
        }
        
        print("❌ No text found in clipboard")
        return ""
    }
    
    private func simulateCopyCommand() {
        // Method 1: Standard Cmd+C
        simulateKeyPress(virtualKey: 8, modifiers: .maskCommand) // 'C' key
        
        // Small delay then try alternative method for stubborn apps
        Thread.sleep(forTimeInterval: 0.05)
        
        // Method 2: Try Cmd+Insert (some apps prefer this)
        simulateKeyPress(virtualKey: 114, modifiers: .maskCommand) // Insert key
    }
    
    private func simulateKeyPress(virtualKey: CGKeyCode, modifiers: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("Failed to create CGEventSource for key \(virtualKey)")
            return
        }
        
        guard let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            print("Failed to create CGEvent for key \(virtualKey)")
            return
        }
        
        keyDownEvent.flags = modifiers
        keyUpEvent.flags = modifiers
        
        keyDownEvent.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.01) // Small delay between key down and up
        keyUpEvent.post(tap: .cghidEventTap)
        
        print("Simulated key press: \(virtualKey) with modifiers: \(modifiers)")
    }
    
    private func getScreenCenterRect() -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        return CGRect(x: mouseLocation.x - 100, y: mouseLocation.y - 15, width: 200, height: 30)
    }
}
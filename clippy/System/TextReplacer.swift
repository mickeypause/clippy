import ApplicationServices
import AppKit
import Carbon

final class TextReplacer {
    private var originalPasteboardContents = NSMutableArray()
    
    func replaceSelectedText(with newText: String) -> Bool {
        guard AXIsProcessTrusted() else {
            showAccessibilityAlert()
            return false
        }
        
        if tryDirectReplacement(newText) {
            return true
        }
        
        if tryKeyboardSimulation(newText) {
            return true
        }
        
        if tryClipboardMethod(newText) {
            return true
        }
        
        showFallbackAlert(newText)
        return false
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
        let status = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, newText as CFString)
        
        return status == .success
    }
    
    private func tryKeyboardSimulation(_ newText: String) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        
        usleep(50000)
        
        let deleteEvent = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
        let deleteUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
        
        deleteEvent?.post(tap: .cghidEventTap)
        usleep(10000)
        deleteUpEvent?.post(tap: .cghidEventTap)
        usleep(50000)
        
        return typeText(newText, source: source)
    }
    
    private func tryClipboardMethod(_ newText: String) -> Bool {
        backupClipboard()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        usleep(100000)
        
        let success = simulatePaste()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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
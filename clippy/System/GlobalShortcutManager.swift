import Carbon
import AppKit

final class GlobalShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let shortcutCallback: () -> Void
    
    private struct HotKeyID {
        static let signature: OSType = OSType(fourCharCodeFrom: "CLPY")
        static let id: UInt32 = 1
    }
    
    init(callback: @escaping () -> Void) {
        self.shortcutCallback = callback
        registerGlobalShortcut()
    }
    
    deinit {
        unregisterGlobalShortcut()
    }
    
    private func registerGlobalShortcut() {
        let hotKeyID = EventHotKeyID(signature: HotKeyID.signature, id: HotKeyID.id)
        
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        ]
        
        let eventHandlerCallback: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            
            let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                OSType(kEventParamDirectObject),
                OSType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr && hotKeyID.id == HotKeyID.id {
                DispatchQueue.main.async {
                    manager.shortcutCallback()
                }
            }
            
            return noErr
        }
        
        let status1 = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerCallback,
            1,
            eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        guard status1 == noErr else {
            print("Failed to install event handler: \(status1)")
            return
        }
        
        let status2 = RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard status2 == noErr else {
            print("Failed to register hot key: \(status2)")
            if let eventHandler = eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
            return
        }
    }
    
    private func unregisterGlobalShortcut() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

private extension OSType {
    init(fourCharCodeFrom string: String) {
        let chars = Array(string.utf8)
        self = OSType(chars[0]) << 24 | OSType(chars[1]) << 16 | OSType(chars[2]) << 8 | OSType(chars[3])
    }
}
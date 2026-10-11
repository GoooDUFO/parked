import Carbon

/// System-wide shortcuts via Carbon's RegisterEventHotKey (needs no Accessibility permission).
final class HotKeys {
    static let shared = HotKeys()

    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var nextID: UInt32 = 1
    private var installed = false

    /// Registers a hotkey and returns its id, or nil if the system refused it.
    @discardableResult
    func register(keyCode: Int, modifiers: Int, _ handler: @escaping () -> Void) -> UInt32? {
        if !installed { installHandler() }
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5052_4B44), id: id) // "PRKD"
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("Parked: failed to register hotkey \(keyCode) (status \(status))")
            return nil
        }
        refs[id] = ref
        handlers[id] = handler
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        handlers[id] = nil
    }

    private func installHandler() {
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { HotKeys.shared.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

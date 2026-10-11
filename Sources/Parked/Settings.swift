import AppKit
import Carbon
import ServiceManagement
import SwiftUI

struct Shortcut: Codable, Equatable {
    var keyCode: Int
    var modifiers: Int  // Carbon modifier mask (cmdKey, optionKey, ...)
    var key: String     // display label for the key, e.g. "P"

    static let `default` = Shortcut(keyCode: kVK_ANSI_P, modifiers: optionKey | cmdKey, key: "P")

    var display: String {
        var s = ""
        if modifiers & controlKey != 0 { s += "⌃" }
        if modifiers & optionKey != 0 { s += "⌥" }
        if modifiers & shiftKey != 0 { s += "⇧" }
        if modifiers & cmdKey != 0 { s += "⌘" }
        return s + key
    }

    init(keyCode: Int, modifiers: Int, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    /// Builds a shortcut from a key press; nil if it has no ⌘/⌥/⌃ (a bare key would hijack typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        guard mods & (cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: Int(event.keyCode), modifiers: mods, key: Shortcut.label(for: event))
    }

    private static func label(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default:
            // charactersIgnoringModifiers still applies ⌥ on some layouts, so use the plain key where possible.
            let chars = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            return chars.isEmpty ? "?" : chars
        }
    }
}

/// App preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published private(set) var parkShortcut: Shortcut
    var onParkHotKey: () -> Void = {}

    private var hotKeyID: UInt32?
    private let defaultsKey = "parkShortcut"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            parkShortcut = saved
        } else {
            parkShortcut = .default
        }
    }

    func activateHotKey() {
        suspendHotKey()
        hotKeyID = HotKeys.shared.register(keyCode: parkShortcut.keyCode, modifiers: parkShortcut.modifiers) { [weak self] in
            self?.onParkHotKey()
        }
    }

    /// Temporarily releases the hotkey, e.g. while recording a new one (so pressing it isn't swallowed).
    func suspendHotKey() {
        if let id = hotKeyID { HotKeys.shared.unregister(id) }
        hotKeyID = nil
    }

    /// Switches to a new shortcut; returns false (and keeps the old one) if macOS won't register it.
    @discardableResult
    func setParkShortcut(_ shortcut: Shortcut) -> Bool {
        let previous = parkShortcut
        parkShortcut = shortcut
        activateHotKey()
        guard hotKeyID != nil else {
            parkShortcut = previous
            activateHotKey()
            return false
        }
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
        return true
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Park shortcut")
                    Text("Opens the question box from anywhere").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder()
            }

            Toggle("Open Parked at login", isOn: $openAtLogin)
                .toggleStyle(.checkbox)
                .onChange(of: openAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        NSLog("Parked: login item change failed: \(error)")
                        openAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Divider()

            HStack {
                Text("Parked \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit Parked") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
    }
}

struct ShortcutRecorder: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var recording = false
    @State private var monitor: Any?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 6) {
                Button(action: toggleRecording) {
                    Text(recording ? "Type shortcut…" : settings.parkShortcut.display)
                        .monospacedDigit()
                        .frame(minWidth: 96)
                }
                .help(recording ? "Press the new shortcut, or Esc to cancel" : "Click to change")

                if settings.parkShortcut != .default && !recording {
                    Button {
                        settings.setParkShortcut(.default)
                    } label: { Image(systemName: "arrow.counterclockwise") }
                        .buttonStyle(.borderless)
                        .help("Reset to \(Shortcut.default.display)")
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        error = nil
        recording = true
        settings.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            guard let shortcut = Shortcut(event: event) else {
                error = "Include ⌘, ⌥ or ⌃"
                return nil
            }
            stopRecording()
            if !settings.setParkShortcut(shortcut) {
                error = "\(shortcut.display) is unavailable"
            }
            return nil
        }
    }

    private func stopRecording() {
        guard recording else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        settings.activateHotKey()
    }
}

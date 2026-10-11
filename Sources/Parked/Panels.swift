import AppKit
import Combine
import SwiftUI

/// Borderless floating panel that sizes itself to its SwiftUI content, can take keyboard focus
/// without activating the app, and keeps its top edge pinned while it grows or shrinks.
final class FloatingPanel: NSPanel {
    var pinnedTop: CGFloat?
    var onEscape: (() -> Void)?

    init<Content: View>(_ content: Content) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentViewController = NSHostingController(rootView: content.panelChrome())
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: self, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.pinnedTop = self.frame.maxY
        }
    }

    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var r = frameRect
        if r.size == frame.size {
            pinnedTop = r.maxY  // a plain move (e.g. the user dragging it): pin the new top
        } else if let top = pinnedTop {
            r.origin.y = top - r.height  // a resize: grow/shrink downward from the pinned top
        }
        super.setFrame(r, display: flag)
        invalidateShadow()
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    func show(topLeft: NSPoint) {
        pinnedTop = topLeft.y
        contentViewController?.view.layoutSubtreeIfNeeded()
        setFrameTopLeftPoint(topLeft)
        makeKeyAndOrderFront(nil)
    }
}

private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private extension View {
    func panelChrome() -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return self
            .background(VisualEffect().clipShape(shape))
            .overlay(shape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

// MARK: - Menu bar item + dropdown

final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var panel: FloatingPanel!
    private var outsideClickMonitor: Any?
    private var countSub: AnyCancellable?

    init(onPark: @escaping () -> Void) {
        super.init()
        panel = FloatingPanel(ReviewView(onPark: { [weak self] in
            self?.close()
            onPark()
        }))
        panel.onEscape = { [weak self] in self?.close() }

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
        }
        countSub = Store.shared.$items.sink { [weak self] items in self?.updateButton(count: items.count) }
    }

    private func updateButton(count: Int) {
        guard let button = statusItem.button else { return }
        let name = count == 0 ? "questionmark.bubble" : "questionmark.bubble.fill"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Parked questions")
        img?.isTemplate = true
        button.image = img
        button.title = count == 0 ? "" : " \(count)"
    }

    @objc private func toggle() {
        panel.isVisible ? close() : open()
    }

    private func open() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        Store.shared.reload()
        TopicStore.shared.reload()
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        let width = panel.frame.width
        var x = buttonRect.minX
        if let visible = screen?.visibleFrame { x = min(x, visible.maxX - width - 8) }
        panel.show(topLeft: NSPoint(x: x, y: buttonRect.minY - 6))
        button.highlight(true)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }
}

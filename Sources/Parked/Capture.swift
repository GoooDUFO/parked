import AppKit
import SwiftUI

final class CaptureModel: ObservableObject {
    @Published var text = ""
    @Published var image: URL?
    @Published var focusToken = 0
    @Published var sourceApp: String?
}

final class CaptureController {
    private let model = CaptureModel()
    private var lastTopLeft: NSPoint?
    private var outsideClickMonitor: Any?

    private lazy var panel: FloatingPanel = {
        let p = FloatingPanel(CaptureView(
            model: model,
            onSave: { [weak self] in self?.save() },
            onCancel: { [weak self] in self?.cancel() },
            onPasteImage: { [weak self] img in self?.attach(img) }
        ))
        p.onEscape = { [weak self] in self?.cancel() }
        p.isMovableByWindowBackground = true
        return p
    }()

    func show() {
        if !panel.isVisible {
            model.text = ""
            discardImage()
            let front = NSWorkspace.shared.frontmostApplication
            model.sourceApp = front?.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : front?.localizedName
        }
        if panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.show(topLeft: startPosition())
            // Clicking elsewhere dismisses the box, but only if nothing has been written or pasted yet.
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self else { return }
                if self.model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && self.model.image == nil {
                    self.cancel()
                }
            }
        }
        model.focusToken += 1
    }

    /// Where the user last left the box (if still on a connected screen), else top-centre of the screen under the mouse.
    private func startPosition() -> NSPoint {
        if let p = lastTopLeft, NSScreen.screens.contains(where: { $0.visibleFrame.insetBy(dx: -1, dy: -1).contains(p) }) {
            return p
        }
        let mouse = NSEvent.mouseLocation
        let frame = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame ?? .zero
        return NSPoint(x: frame.midX - CaptureView.width / 2, y: frame.maxY - frame.height * 0.2)
    }

    private func hide() {
        if panel.isVisible { lastTopLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY) }
        panel.orderOut(nil)
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }

    private func attach(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("parked-\(UUID().uuidString).png")
        guard (try? png.write(to: tmp)) != nil else { return }
        discardImage()
        model.image = tmp
    }

    private func save() {
        let text = model.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || model.image != nil else { return cancel() }
        Store.shared.add(question: text.isEmpty ? "(see image)" : text,
                         screenshot: model.image, app: model.sourceApp)
        model.image = nil
        model.text = ""
        hide()
    }

    private func cancel() {
        discardImage()
        model.text = ""
        hide()
    }

    private func discardImage() {
        if let url = model.image { try? FileManager.default.removeItem(at: url) }
        model.image = nil
    }
}

struct CaptureView: View {
    static let width: CGFloat = 480

    @ObservedObject var model: CaptureModel
    let onSave: () -> Void
    let onCancel: () -> Void
    let onPasteImage: (NSImage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                QuestionEditor(text: $model.text,
                               focusToken: model.focusToken,
                               onSubmit: onSave,
                               onCancel: onCancel,
                               onPasteImage: onPasteImage)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor)))

                if let url = model.image, let img = NSImage(contentsOf: url) {
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 120)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.25)))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button {
                            try? FileManager.default.removeItem(at: url)
                            model.image = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                        .help("Remove image")
                    }
                }
            }
            .frame(height: 120)

            HStack {
                Text(model.image == nil ? "⌘V paste image" : "⌘V replace image")
                Spacer()
                Text("⌘↩ park   esc cancel")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
        }
        .padding(10)
        .frame(width: Self.width)
        .background(DragToMove())
    }
}

/// Lets the empty areas of the box (edges, hint row) drag the whole window.
private struct DragToMove: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture())
        } else {
            Color.clear
        }
    }
}

// MARK: - Native multi-line editor

/// NSTextView wrapper: ↩ is a normal new line, ⌘↩ submits, esc cancels,
/// and pasting an image (e.g. a clipboard screenshot) attaches it instead of inserting text.
struct QuestionEditor: NSViewRepresentable {
    @Binding var text: String
    let focusToken: Int
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onPasteImage: (NSImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let tv = QuestionTextView()
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.font = .systemFont(ofSize: 15)
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.placeholder = "Park a question for later…"
        scroll.documentView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? QuestionTextView else { return }
        tv.onSubmit = onSubmit
        tv.onCancel = onCancel
        tv.onPasteImage = onPasteImage
        if tv.string != text {
            tv.string = text
            tv.needsDisplay = true
        }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
                tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuestionEditor
        var lastFocusToken = -1
        init(_ parent: QuestionEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

final class QuestionTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onPasteImage: ((NSImage) -> Void)?
    var placeholder = ""

    override func keyDown(with event: NSEvent) {
        let isReturn = event.keyCode == 36 || event.keyCode == 76
        if isReturn && event.modifierFlags.contains(.command) {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    // The app has no Edit menu (menu bar app), so standard editing shortcuts must be handled here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command || flags == [.command, .shift] else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "v": paste(nil)
        case "c": copy(nil)
        case "x": cut(nil)
        case "a": selectAll(nil)
        case "z": if flags.contains(.shift) { undoManager?.redo() } else { undoManager?.undo() }
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    override func paste(_ sender: Any?) {
        let pb = NSPasteboard.general
        let types = pb.types ?? []
        let hasImageData = types.contains(.png) || types.contains(.tiff)
        let isRichText = types.contains(.html) || types.contains(.rtf)
        let imageFile = pb.readObjects(forClasses: [NSURL.self],
                                       options: [.urlReadingContentsConformToTypes: ["public.image"]])?.first as? URL
        // Screenshots / copied images → attach. Copied text (even with images embedded) → paste as text.
        if let imageFile, let img = NSImage(contentsOf: imageFile) {
            onPasteImage?(img)
        } else if hasImageData, !isRichText || pb.string(forType: .string) == nil, let img = NSImage(pasteboard: pb) {
            onPasteImage?(img)
        } else {
            pasteAsPlainText(sender)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerOrigin.x + padding, y: textContainerOrigin.y)
        (placeholder as NSString).draw(at: origin, withAttributes: [
            .font: font ?? .systemFont(ofSize: 15),
            .foregroundColor: NSColor.placeholderTextColor,
        ])
    }
}

import AppKit
import Carbon

@main
enum ParkedApp {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let capture = CaptureController()
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController(onPark: { [capture] in capture.show() })

        // ⌥⌘P: park a question.
        HotKeys.shared.register(keyCode: kVK_ANSI_P, modifiers: optionKey | cmdKey) { [weak self] in
            self?.menuBar?.close()
            self?.capture.show()
        }
    }
}

import AppKit

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

        // Global shortcut (⌥⌘P by default, changeable in Settings): park a question.
        AppSettings.shared.onParkHotKey = { [weak self] in
            self?.menuBar?.close()
            self?.capture.show()
        }
        AppSettings.shared.activateHotKey()
    }
}

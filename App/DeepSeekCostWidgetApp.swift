import SwiftUI
import AppKit

@main
struct DeepSeekCostWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = DataManager.shared
        MenuBarManager.shared.start()

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleURL(_ event: NSAppleEventDescriptor?, withReplyEvent: NSAppleEventDescriptor?) {
        guard let s = event?.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              URL(string: s)?.scheme == "deepseekcostwidget" else { return }
        DispatchQueue.main.async {
            MenuBarManager.shared.showPopover()
            DataManager.shared.refresh()
        }
    }
}

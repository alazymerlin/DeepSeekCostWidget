import SwiftUI
import AppKit

final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        AppGroup.clearError()
        updateIcon(nil)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.animates = false
        popover?.contentViewController?.view.frame = NSRect(x: 0, y: 0, width: 320, height: 400)
        popover?.contentViewController = NSHostingController(
            rootView: PopoverView()
        )

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResizePopover"),
            object: nil, queue: .main
        ) { [weak self] n in
            guard let size = n.object as? NSSize else { return }
            self?.popover?.contentSize = size
        }

        Task { @MainActor in
            DataManager.shared.refresh()
        }
    }

    func updateIcon(_ costData: CostData?) {
        let hasData = costData != nil || AppGroup.loadCostData() != nil
        let hasError = AppGroup.loadError() != nil && !hasData

        let iconName = hasError ? "exclamationmark.triangle.fill" : "chart.bar.fill"
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)

        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "DeepSeek")?
            .withSymbolConfiguration(symbolConfig) {
            statusItem?.button?.image = image
        }

        statusItem?.button?.title = ""
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make popover window key so transient behavior works
            popover.contentViewController?.view.window?.makeKey()
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                if let popoverWindow = popover.contentViewController?.view.window,
                   event.window != popoverWindow {
                    self?.closePopover()
                }
                return event
            }
            Task { @MainActor in
                DataManager.shared.updateIconHandler = { [weak self] data in
                    self?.updateIcon(data)
                }
            }
        }
    }

    func showPopover() {
        guard let popover, let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                if let pw = popover.contentViewController?.view.window, event.window != pw {
                    self?.closePopover()
                }
                return event
            }
        }
    }

    private func closePopover() {
        popover?.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

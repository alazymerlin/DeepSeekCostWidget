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
            button.target = self
            button.action = #selector(handleStatusItemClick)
            // 左右键都要接住，否则右键事件根本不会送到 action
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover = NSPopover()
        // 初始给个近似值，随后由 SwiftUI 内容实测高度自动调整
        popover?.contentSize = NSSize(width: 320, height: 380)
        popover?.behavior = .transient
        popover?.animates = false
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

    /// 左键开面板，右键弹菜单（退出从面板底栏挪到了这里）
    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let open = NSMenuItem(title: L10n.openPanel, action: #selector(togglePopover), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let refresh = NSMenuItem(title: L10n.refresh, action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: L10n.quit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        if let button = statusItem?.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 4),
                       in: button)
        }
    }

    @objc private func refreshNow() {
        Task { @MainActor in DataManager.shared.refresh() }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
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

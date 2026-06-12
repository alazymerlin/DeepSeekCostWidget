import SwiftUI
import AppKit

final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(nil)

        if let button = statusItem?.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: PopoverView()
        )

        // 初始刷新
        Task { @MainActor in
            DataManager.shared.refresh()
        }
    }

    func updateIcon(_ costData: CostData?) {
        let hasData = costData != nil
        let hasError = AppGroup.loadError() != nil && costData == nil

        let iconName = hasError ? "exclamationmark.triangle.fill" : "chart.bar.fill"
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)

        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "DeepSeek")?
            .withSymbolConfiguration(symbolConfig) {
            statusItem?.button?.image = image
        }

        statusItem?.button?.title = hasData ? "" : "  DeepSeek"
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            Task { @MainActor in
                DataManager.shared.updateIconHandler = { [weak self] data in
                    self?.updateIcon(data)
                }
            }
        }
    }
}

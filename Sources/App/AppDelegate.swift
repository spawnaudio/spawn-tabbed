import AppKit
import ApplicationServices
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var autoAddMenuItem: NSMenuItem?
    private var compactModeMenuItem: NSMenuItem?
    private var trustPollTimer: Timer?
    private var launchAtLoginMenuItem: NSMenuItem?
    private let engine = AXWindowEngine()
    private lazy var controller = TabGroupController(engine: engine)

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        TabbedConfig.ensureFileExists()
        setUpStatusItem()

        let trusted = ensureAccessibilityPermission()
        NSLog("[Tabbed] accessibility trusted = \(trusted)")
        guard trusted else {
            // Keep the menu item available while the user grants access,
            // and start as soon as it is granted — no relaunch needed.
            statusItem?.button?.appearsDisabled = true
            trustPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.startWhenTrusted() }
            }
            return
        }
        startController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Inactive tabs are parked off-screen; put every window back first.
        controller.restoreAllWindows()
    }

    private func startWhenTrusted() {
        guard AXIsProcessTrusted() else { return }
        trustPollTimer?.invalidate()
        trustPollTimer = nil
        statusItem?.button?.appearsDisabled = false
        startController()
    }

    private func startController() {
        controller.start()
        NSLog("[Tabbed] controller started — global ⌘-drag monitor active")
    }

    // MARK: - Status bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle.angled",
                                     accessibilityDescription: "Tabbed")
        let menu = NSMenu()
        menu.addItem(withTitle: "Tabbed", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let autoAddItem = menu.addItem(
            withTitle: "Auto-add New Windows to Stack",
            action: #selector(toggleAutoAddNewWindowsToStack),
            keyEquivalent: ""
        )
        autoAddItem.target = self
        autoAddItem.state = AppSettings.autoAddNewWindowsToStack ? .on : .off
        autoAddMenuItem = autoAddItem

        let compactItem = menu.addItem(
            withTitle: "Always Use Compact Mode",
            action: #selector(toggleAlwaysUseCompactMode),
            keyEquivalent: ""
        )
        compactItem.target = self
        compactItem.state = AppSettings.alwaysUseCompactMode ? .on : .off
        compactModeMenuItem = compactItem

        let loginItem = menu.addItem(
            withTitle: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginMenuItem = loginItem

        menu.addItem(.separator())
        menu.addItem(withTitle: "Edit Configuration…",
                     action: #selector(editConfig), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reload Configuration",
                     action: #selector(reloadConfig), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Accessibility Settings…",
                     action: #selector(openAXSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tabbed",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleAutoAddNewWindowsToStack() {
        let enabled = !controller.autoAddNewWindowsToStack
        controller.setAutoAddNewWindowsToStack(enabled)
        autoAddMenuItem?.state = enabled ? .on : .off
    }

    @objc private func toggleAlwaysUseCompactMode() {
        let enabled = !controller.alwaysUseCompactMode
        controller.setAlwaysUseCompactMode(enabled)
        compactModeMenuItem?.state = enabled ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            NSLog("[Tabbed] launch at login: \(error)")
        }
        if service.status == .requiresApproval {
            // macOS wants the user to allow it in Login Items first.
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLoginMenuItem?.state = service.status == .enabled ? .on : .off
    }

    @objc private func reloadConfig() {
        controller.reloadConfig()
    }

    @objc private func editConfig() {
        NSWorkspace.shared.open(TabbedConfig.ensureFileExists())
    }

    @objc private func openAXSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Permissions

    private func ensureAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}

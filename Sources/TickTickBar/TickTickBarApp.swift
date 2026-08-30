import SwiftUI
import ServiceManagement

@main
struct TickTickBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverRoot()
                .environmentObject(store)
        } label: {
            HStack(spacing: 3) {
                if let icon = Self.menubarIcon {
                    Image(nsImage: icon)
                } else {
                    Image(systemName: "checkmark.circle")
                }
                if store.openCount > 0 {
                    Text("\(store.openCount)")
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Poll refresh + launch load are driven by AppStore.
    }
}

// Launch-at-login via SMAppService (macOS 13+, no helper app needed).
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() throws {
        if isEnabled {
            try SMAppService.mainApp.unregister()
        } else {
            try SMAppService.mainApp.register()
        }
    }
}

extension TickTickBarApp {
    /// TickTick mark for the menubar, from the bundle Resources dir.
    static let menubarIcon: NSImage? = {
        let path = Bundle.main.path(forResource: "ticktick", ofType: "svg")
            ?? "../ticktick.svg" // dev fallback: running from the package root
        guard let img = NSImage(contentsOfFile: path) else { return nil }
        img.size = NSSize(width: 16, height: 16)
        img.isTemplate = true
        return img
    }()
}

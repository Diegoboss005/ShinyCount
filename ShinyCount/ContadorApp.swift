import SwiftUI

@main
struct ContadorApp: App {
    init() {
        // Check for updates silently on launch
        UpdateChecker.checkForUpdates(silent: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

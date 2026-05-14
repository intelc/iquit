import SwiftUI

@main
struct iQuitApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        MenuBarExtra("iQuit", systemImage: model.isPaused ? "pause.circle" : "moon.zzz.fill") {
            MenuBarView()
                .environmentObject(model)
                .environmentObject(updater)
        }
        .menuBarExtraStyle(.window)

        Window("iQuit", id: "main") {
            DashboardView()
                .environmentObject(model)
                .environmentObject(updater)
        }
        .defaultSize(width: 960, height: 640)

        Settings {
            PreferencesView()
                .environmentObject(model)
                .environmentObject(updater)
                .padding(20)
                .frame(width: 460)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}

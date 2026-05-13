import SwiftUI

@main
struct iQuitApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("iQuit", systemImage: model.isPaused ? "pause.circle" : "moon.zzz.fill") {
            MenuBarView()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Window("iQuit", id: "main") {
            DashboardView()
                .environmentObject(model)
        }
        .defaultSize(width: 960, height: 640)

        Settings {
            PreferencesView()
                .environmentObject(model)
                .padding(20)
                .frame(width: 460)
        }
    }
}

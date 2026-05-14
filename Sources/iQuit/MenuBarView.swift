import AppKit
import iQuitCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !model.hasCompletedOnboarding {
                Button {
                    openWindow(id: "main")
                    focusMainWindow()
                    model.showOnboarding()
                } label: {
                    Label("Finish Setup", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if !model.pendingCleanups.isEmpty {
                pendingSection
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Next Up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if model.upcomingCleanups.isEmpty {
                    Text("No cleanup actions coming up.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    ForEach(model.upcomingCleanups) { upcoming in
                        UpcomingCleanupRow(upcoming: upcoming)
                            .environmentObject(model)
                    }
                }
            }

            Divider()

            HStack {
                Button {
                    openWindow(id: "main")
                    focusMainWindow()
                } label: {
                    Label("Open iQuit", systemImage: "macwindow")
                }

                Spacer()

                Button("Quit iQuit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func focusMainWindow() {
        DispatchQueue.main.async {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.windows
                .filter { $0.title == "iQuit" }
                .forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("iQuit")
                        .font(.title2.weight(.semibold))
                    Text(model.lastEventMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: $model.settings.isEnabled)
                    .toggleStyle(.switch)
            }

            if model.isPaused || !model.pendingCleanups.isEmpty {
                HStack(spacing: 8) {
                    if model.isPaused {
                        StatusPill(title: "Paused", systemImage: "pause.circle", tint: .orange)
                    }
                    if !model.pendingCleanups.isEmpty {
                        StatusPill(
                            title: "\(model.pendingCleanups.count) pending",
                            systemImage: "tray",
                            tint: .blue
                        )
                    }
                }
            }
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(model.pendingCleanups.prefix(3)) { cleanup in
                PendingCleanupRow(cleanup: cleanup, compact: true)
            }
        }
    }
}

private struct UpcomingCleanupRow: View {
    @EnvironmentObject private var model: AppModel
    var upcoming: AppModel.UpcomingCleanup

    var body: some View {
        HStack(spacing: 9) {
            AppIconView(icon: upcoming.app.icon, size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(upcoming.app.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(model.idleDescription(for: upcoming.app))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(model.upcomingDescription(upcoming), systemImage: upcoming.trigger == .visibleWindow ? "macwindow" : "power")
                .font(.caption.weight(.semibold))
                .foregroundStyle(upcoming.trigger == .visibleWindow ? .blue : .red)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

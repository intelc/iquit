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
                Text("Running Apps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(model.sortedRunningApps.prefix(6)) { app in
                    CompactAppRow(app: app)
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

            HStack(spacing: 8) {
                StatusPill(
                    title: model.isPaused ? "Paused" : "Watching",
                    systemImage: model.isPaused ? "pause.circle" : "eye",
                    tint: model.isPaused ? .orange : .green
                )
                StatusPill(
                    title: "\(model.pendingCleanups.count) pending",
                    systemImage: "tray",
                    tint: model.pendingCleanups.isEmpty ? .secondary : .blue
                )
                StatusPill(
                    title: model.activeAppName,
                    systemImage: "cursorarrow.rays",
                    tint: .indigo
                )
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

private struct CompactAppRow: View {
    @EnvironmentObject private var model: AppModel
    var app: RunningApp

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(icon: app.icon, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(model.idleDescription(for: app))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(ruleSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var ruleSummary: String {
        let policy = model.policy(for: app)
        let windowText = switch policy.visibleWindowAction {
        case .ask: "Win Ask"
        case .hide: "Win Hide"
        case .quit: "Win Quit"
        case .off: ""
        }
        let quitText = switch policy.idleQuitAction {
        case .ask: "Quit Ask"
        case .quit: "Auto Quit"
        case .off: ""
        }
        return [windowText, quitText].filter { !$0.isEmpty }.joined(separator: " + ").nilIfEmpty ?? "Off"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

import AppKit
import iQuitCore
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            VStack(alignment: .leading, spacing: 6) {
                Text("NEXT UP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.blue)
                    .textCase(.uppercase)

                VStack(spacing: 1) {
                    if model.upcomingCleanups.isEmpty {
                        Text("Nothing close.")
                            .font(.callout.weight(.medium))
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
                .padding(.vertical, 2)
            }
            .padding(10)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 330)
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
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("iQuit")
                        .font(.title3.weight(.bold))

                    Text("v\(Self.appVersion)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(model.lastEventMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if model.isPaused {
                Text("Paused")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if !model.pendingCleanups.isEmpty {
                Text("\(model.pendingCleanups.count) pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            Toggle("", isOn: $model.settings.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REVIEW")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)

            ForEach(model.pendingCleanups.prefix(3)) { cleanup in
                PendingCleanupRow(cleanup: cleanup, compact: true)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UpcomingCleanupRow: View {
    @EnvironmentObject private var model: AppModel
    var upcoming: AppModel.UpcomingCleanup

    var body: some View {
        HStack(spacing: 8) {
            AppIconView(icon: upcoming.app.icon, size: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(upcoming.app.displayName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(model.idleDescription(for: upcoming.app))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(model.upcomingDescription(upcoming))
                .font(.caption.weight(.bold))
                .foregroundStyle(upcoming.trigger == .visibleWindow ? .blue : .red)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

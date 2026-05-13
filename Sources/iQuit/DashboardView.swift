import iQuitCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
                .environmentObject(model)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !model.pendingCleanups.isEmpty {
                        PendingReviewPanel()
                            .environmentObject(model)
                    }

                    ForEach(model.sortedRunningApps) { app in
                        AppPolicyRow(app: app)
                            .environmentObject(model)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .sheet(isPresented: $model.isOnboardingPresented) {
            OnboardingView()
                .environmentObject(model)
        }
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Label("iQuit", systemImage: "moon.zzz.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .labelStyle(.titleAndIcon)

                Toggle("Enabled", isOn: $model.settings.isEnabled)
                    .toggleStyle(.switch)

                StatusPill(
                    title: model.isPaused ? "Paused" : "Watching",
                    systemImage: model.isPaused ? "pause.circle" : "eye",
                    tint: model.isPaused ? .orange : .green
                )
                StatusPill(title: model.activeAppName, systemImage: "cursorarrow.rays", tint: .indigo)
                Button {
                    model.requestAccessibilityAccess()
                } label: {
                    Label(
                        model.accessibilityTrusted ? "Window access" : "Enable window access",
                        systemImage: model.accessibilityTrusted ? "checkmark.shield" : "exclamationmark.shield"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(model.accessibilityTrusted ? .green : .orange)
                .help("Accessibility access lets iQuit minimize individual windows instead of hiding the whole app.")

                Spacer(minLength: 12)

                HeaderMetric(value: "\(model.runningApps.count)", label: "apps", systemImage: "square.grid.2x2")
                HeaderMetric(value: "\(model.pendingCleanups.count)", label: "review", systemImage: "tray")
                HeaderMetric(value: "\(model.settings.policies.count)", label: "rules", systemImage: "slider.horizontal.3")
            }

            HStack(spacing: 14) {
                DefaultRuleControl(
                    title: "Visible windows",
                    systemImage: "macwindow",
                    tint: .blue,
                    minutes: $model.settings.defaultVisibleWindowMinutes
                )

                DefaultRuleControl(
                    title: "Idle quit",
                    systemImage: "power",
                    tint: .red,
                    minutes: $model.settings.defaultIdleQuitMinutes
                )

                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.bar)
    }
}

private struct HeaderMetric: View {
    var value: String
    var label: String
    var systemImage: String

    var body: some View {
        Label {
            Text(value)
                .font(.callout.weight(.semibold).monospacedDigit())
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

private struct PendingReviewPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Review", systemImage: "tray.full")
                    .font(.headline)
                Spacer()
            }

            ForEach(model.pendingCleanups) { cleanup in
                PendingCleanupRow(cleanup: cleanup, compact: false)
                    .environmentObject(model)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PendingCleanupRow: View {
    @EnvironmentObject private var model: AppModel
    var cleanup: PendingCleanup
    var compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: cleanup.action == .quit ? "power" : "eye.slash")
                .foregroundStyle(cleanup.action == .quit ? .red : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(cleanup.displayName)
                    .font(.callout.weight(.semibold))
                Text(cleanup.trigger.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if cleanup.trigger == .visibleWindow {
                Button {
                    model.approve(cleanup, as: .hide)
                } label: {
                    Image(systemName: "eye.slash")
                }
                .help("Hide")
            }

            Button {
                model.approve(cleanup, as: .quit)
            } label: {
                Image(systemName: "power")
            }
            .help("Quit")

            Button {
                model.skip(cleanup)
            } label: {
                Image(systemName: "xmark")
            }
            .help("Skip")
        }
        .buttonStyle(.borderless)
        .padding(compact ? 8 : 10)
        .background(.quaternary.opacity(compact ? 0.6 : 0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AppPolicyRow: View {
    @EnvironmentObject private var model: AppModel
    var app: RunningApp

    var body: some View {
        let policy = model.policy(for: app)

        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { policy.isProtected },
                set: { model.setProtected($0, for: app) }
            )) {
                Image(systemName: policy.isProtected ? "lock.fill" : "lock.open")
                    .frame(width: 16, height: 16)
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .frame(width: 34)
            .help("Never hide or quit this app automatically")

            AppIconView(icon: app.icon, size: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(app.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if app.isActive {
                        StatusPill(title: "Active", systemImage: "dot.radiowaves.left.and.right", tint: .green)
                    }
                }

                Text("\(model.idleDescription(for: app)) - \(app.bundleID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 190, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            RuleControl(
                title: "Windows",
                systemImage: app.hasVisibleWindows ? "macwindow" : "macwindow.badge.plus",
                isOn: Binding(
                    get: { policy.visibleWindowCleanupEnabled },
                    set: { model.setVisibleWindowCleanupEnabled($0, for: app) }
                ),
                tint: .blue,
                minutes: Binding(
                    get: { policy.visibleWindowMinutes },
                    set: { model.setVisibleWindowMinutes($0, for: app) }
                )
            )

            RuleControl(
                title: "Quit",
                systemImage: "power",
                isOn: Binding(
                    get: { policy.idleQuitEnabled },
                    set: { model.setIdleQuitEnabled($0, for: app) }
                ),
                tint: .red,
                offText: "Never",
                minutes: Binding(
                    get: { policy.idleQuitMinutes },
                    set: { model.setIdleQuitMinutes($0, for: app) }
                )
            )

            Menu {
                Button {
                    model.cleanupNow(app, action: .hide)
                } label: {
                    Label("Hide Now", systemImage: "eye.slash")
                }

                Button(role: .destructive) {
                    model.cleanupNow(app, action: .quit)
                } label: {
                    Label("Quit Now", systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 44)
            .help("Manual actions")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct RuleControl: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool
    var tint: Color
    var offText: String?
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $isOn) {
                Label(title, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .tint(tint)
            .frame(width: 96)

            Stepper(value: $minutes, in: 1 ... 720, step: 5) {
                Text(isOn ? "\(minutes)m" : (offText ?? "Off"))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(isOn ? tint : .secondary)
                    .frame(width: 54, alignment: .trailing)
            }
            .disabled(!isOn)
            .opacity(isOn ? 1 : 0.65)
            .frame(width: 118)
        }
        .frame(width: 222)
    }
}

private struct DefaultRuleControl: View {
    var title: String
    var systemImage: String
    var tint: Color
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 132, alignment: .leading)

            Stepper(value: $minutes, in: 1 ... 720, step: 5) {
                Text("\(minutes)m")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
            .frame(width: 104)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Defaults")
                .font(.headline)

            Stepper(value: $model.settings.defaultVisibleWindowMinutes, in: 1 ... 720, step: 5) {
                HStack {
                    Text("Visible windows")
                    Spacer()
                    Text("\(model.settings.defaultVisibleWindowMinutes)m")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $model.settings.defaultIdleQuitMinutes, in: 1 ... 720, step: 5) {
                HStack {
                    Text("Idle quit")
                    Spacer()
                    Text("\(model.settings.defaultIdleQuitMinutes)m")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

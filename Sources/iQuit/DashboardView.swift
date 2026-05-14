import AppKit
import iQuitCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isProtectedSectionExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar()
                .environmentObject(model)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !model.protectedRunningApps.isEmpty {
                        ProtectedAppsSection(
                            apps: model.protectedRunningApps,
                            isExpanded: $isProtectedSectionExpanded
                        )
                        .environmentObject(model)
                    }

                    if !model.pendingCleanups.isEmpty {
                        PendingReviewPanel()
                            .environmentObject(model)
                    }

                    ForEach(model.cleanupRunningApps) { app in
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

private struct ProtectedAppsSection: View {
    @EnvironmentObject private var model: AppModel
    var apps: [RunningApp]
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(apps) { app in
                    AppPolicyRow(app: app)
                        .environmentObject(model)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("Protected")
                    .font(.callout.weight(.semibold))

                Text("\(apps.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())

                Spacer()

                Text("Ignored by iQuit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Text("iQuit")
                    .font(.title2.weight(.semibold))

                Toggle("Enabled", isOn: $model.settings.isEnabled)
                    .toggleStyle(.switch)

                if !model.accessibilityTrusted {
                    Button {
                        model.requestAccessibilityAccess()
                    } label: {
                        Label(
                            model.isCheckingAccessibility ? "Checking window access" : "Enable window access",
                            systemImage: "exclamationmark.shield"
                        )
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
                    .help("Accessibility access lets iQuit minimize individual windows instead of hiding the whole app.")
                }

                Spacer(minLength: 12)

                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!updater.canCheckForUpdates)

                if !model.pendingCleanups.isEmpty {
                    HeaderMetric(value: "\(model.pendingCleanups.count)", label: "review", systemImage: "tray")
                }
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

                LoginItemControl()
                    .environmentObject(model)

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

            WindowRuleControl(
                title: "Windows",
                systemImage: app.hasVisibleWindows ? "macwindow" : "macwindow.badge.plus",
                action: Binding(
                    get: { policy.visibleWindowAction },
                    set: { model.setVisibleWindowAction($0, for: app) }
                ),
                tint: .blue,
                minutes: Binding(
                    get: { policy.visibleWindowMinutes },
                    set: { model.setVisibleWindowMinutes($0, for: app) }
                )
            )
            .disabled(policy.isProtected)

            IdleQuitRuleControl(
                title: "Quit",
                systemImage: "power",
                action: Binding(
                    get: { policy.idleQuitAction },
                    set: { model.setIdleQuitAction($0, for: app) }
                ),
                tint: .red,
                minutes: Binding(
                    get: { policy.idleQuitMinutes },
                    set: { model.setIdleQuitMinutes($0, for: app) }
                )
            )
            .disabled(policy.isProtected)

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
            .disabled(policy.isProtected)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(policy.isProtected ? 0.54 : 1)
    }
}

private struct WindowRuleControl: View {
    var title: String
    var systemImage: String
    @Binding var action: AppPolicy.VisibleWindowAction
    var tint: Color
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    action = .ask
                } label: {
                    Label("Ask", systemImage: "questionmark.bubble")
                }

                Button {
                    action = .hide
                } label: {
                    Label("Always Hide", systemImage: "eye.slash")
                }

                Divider()

                Button {
                    action = .off
                } label: {
                    Label("Off", systemImage: "pause.circle")
                }
            } label: {
                Label(windowActionTitle(action), systemImage: systemImage)
                    .lineLimit(1)
                    .frame(width: 106, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .tint(tint)
            .help("Choose whether the window timer asks first or acts automatically.")

            MinuteComboBox(minutes: $minutes, disabledLabel: "Off", isEnabled: action != .off)
        }
        .frame(width: 220)
    }

    private func windowActionTitle(_ action: AppPolicy.VisibleWindowAction) -> String {
        switch action {
        case .ask: "Ask"
        case .hide: "Always Hide"
        case .off: "Off"
        }
    }
}

private struct IdleQuitRuleControl: View {
    var title: String
    var systemImage: String
    @Binding var action: AppPolicy.IdleQuitAction
    var tint: Color
    @Binding var minutes: Int

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button {
                    action = .ask
                } label: {
                    Label("Ask", systemImage: "questionmark.bubble")
                }

                Button(role: .destructive) {
                    action = .quit
                } label: {
                    Label("Always Quit", systemImage: "power")
                }

                Divider()

                Button {
                    action = .off
                } label: {
                    Label("Never", systemImage: "pause.circle")
                }
            } label: {
                Label(idleActionTitle(action), systemImage: systemImage)
                    .lineLimit(1)
                    .frame(width: 106, alignment: .leading)
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .tint(tint)
            .help("Choose whether the idle-quit timer asks first or quits automatically.")

            MinuteComboBox(minutes: $minutes, disabledLabel: "Never", isEnabled: action != .off)
        }
        .frame(width: 220)
    }

    private func idleActionTitle(_ action: AppPolicy.IdleQuitAction) -> String {
        switch action {
        case .ask: "Ask"
        case .quit: "Always Quit"
        case .off: "Never"
        }
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

            MinuteComboBox(minutes: $minutes)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LoginItemControl: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: Binding(
                get: { model.settings.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                Text("Start at login")
                    .font(.callout.weight(.semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Text(model.loginItemStatusDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .help("Open iQuit automatically after you sign in to your Mac.")
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Defaults")
                .font(.headline)

            HStack {
                Text("Visible windows")
                Spacer()
                MinuteComboBox(minutes: $model.settings.defaultVisibleWindowMinutes)
            }

            HStack {
                Text("Idle quit")
                Spacer()
                MinuteComboBox(minutes: $model.settings.defaultIdleQuitMinutes)
            }

            Toggle(isOn: Binding(
                get: { model.settings.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                HStack {
                    Text("Start iQuit when you sign in")
                    Spacer()
                    Text(model.loginItemStatusDescription)
                        .foregroundStyle(.secondary)
                }
            }
            .help("Open iQuit automatically after you sign in to your Mac.")
        }
    }
}

private struct MinuteComboBox: View {
    @Binding var minutes: Int
    var disabledLabel: String? = nil
    var isEnabled: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            MinuteComboBoxField(minutes: $minutes, disabledLabel: disabledLabel, isEnabled: isEnabled)
                .frame(width: isEnabled ? 58 : 76)

            if isEnabled {
                Text("m")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 12, alignment: .leading)
            }
        }
        .frame(width: isEnabled ? 74 : 76, alignment: .leading)
    }
}

private struct MinuteComboBoxField: NSViewRepresentable {
    @Binding var minutes: Int
    var disabledLabel: String? = nil
    var isEnabled: Bool = true

    private let presets = [5, 10, 15, 20, 30, 45, 60, 90]
    private let range = 1 ... 119

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.addItems(withObjectValues: presets.map { "\($0)" })
        comboBox.completes = false
        comboBox.isEditable = true
        comboBox.numberOfVisibleItems = presets.count
        comboBox.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        comboBox.controlSize = .small
        comboBox.frame = NSRect(x: 0, y: 0, width: 58, height: 24)
        comboBox.delegate = context.coordinator
        comboBox.target = context.coordinator
        comboBox.action = #selector(Coordinator.commit)
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.parent = self
        comboBox.isEnabled = isEnabled
        comboBox.stringValue = isEnabled ? "\(clamped(minutes))" : (disabledLabel ?? "\(clamped(minutes))")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func clamped(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: MinuteComboBoxField

        init(parent: MinuteComboBoxField) {
            self.parent = parent
        }

        @objc func commit(_ sender: NSComboBox) {
            commitValue(from: sender)
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let sender = notification.object as? NSComboBox else { return }
            commitValue(from: sender)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let sender = notification.object as? NSComboBox else { return }
            commitValue(from: sender)
        }

        private func commitValue(from comboBox: NSComboBox) {
            let rawText = comboBox.stringValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "m", with: "", options: .caseInsensitive)
            let rawValue = Int(rawText) ?? parent.minutes
            let value = min(parent.range.upperBound, max(parent.range.lowerBound, rawValue))
            parent.minutes = value
            comboBox.stringValue = "\(value)"
        }
    }
}

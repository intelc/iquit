import AppKit
import Combine
import Foundation
import iQuitCore

@MainActor
final class AppModel: NSObject, ObservableObject {
    @Published private(set) var runningApps: [RunningApp] = []
    @Published private(set) var pendingCleanups: [PendingCleanup] = []
    @Published private(set) var lastEventMessage = "Watching quietly."
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var loginItemStatusDescription = LoginItemManager.statusDescription
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var isOnboardingPresented: Bool
    @Published var settings: AppSettings {
        didSet { SettingsStore.save(settings) }
    }

    private let decisionEngine = IdleDecisionEngine()
    private let workspace = NSWorkspace.shared
    private var askPromptController: AskPromptWindowController?
    private var timer: Timer?
    private var cooldowns: [String: Date] = [:]
    private let cooldownDuration: TimeInterval = 10 * 60
    private let promptDuration: TimeInterval = 30

    override init() {
        settings = SettingsStore.load()
        hasCompletedOnboarding = SettingsStore.hasCompletedOnboarding
        isOnboardingPresented = !SettingsStore.hasCompletedOnboarding
        super.init()
        accessibilityTrusted = AccessibilityWindowManager.isTrusted()
        askPromptController = AskPromptWindowController(
            onHide: { [weak self] cleanup in
                self?.approve(cleanup, as: .hide)
            },
            onQuit: { [weak self] cleanup in
                self?.approve(cleanup, as: .quit)
            },
            onIgnore: { [weak self] cleanup in
                self?.ignoreApp(cleanup)
            },
            onSkip: { [weak self] cleanup in
                self?.skip(cleanup)
            },
            onTimeout: { [weak self] cleanup in
                self?.timeout(cleanup)
            }
        )
        observeWorkspace()
        syncLoginItemWithPreference()
        refreshRunningApplications()
        startTimer()
    }

    var sortedRunningApps: [RunningApp] {
        runningApps.sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var activeAppName: String {
        runningApps.first(where: \.isActive)?.displayName ?? "No active app"
    }

    var isPaused: Bool {
        !settings.isEnabled
    }

    func policy(for app: RunningApp) -> AppPolicy {
        settings.policy(for: app.bundleID, displayName: app.displayName)
    }

    func setVisibleWindowCleanupEnabled(_ isEnabled: Bool, for app: RunningApp) {
        var policy = policy(for: app)
        policy.visibleWindowCleanupEnabled = isEnabled
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
        lastEventMessage = isEnabled ? "\(app.displayName) window cleanup is on." : "\(app.displayName) window cleanup is off."
    }

    func setIdleQuitEnabled(_ isEnabled: Bool, for app: RunningApp) {
        var policy = policy(for: app)
        policy.idleQuitEnabled = isEnabled
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
        lastEventMessage = isEnabled ? "\(app.displayName) idle quit is on." : "\(app.displayName) idle quit is off."
    }

    func setVisibleWindowMinutes(_ minutes: Int, for app: RunningApp) {
        var policy = policy(for: app)
        policy.visibleWindowMinutes = max(1, minutes)
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
    }

    func setIdleQuitMinutes(_ minutes: Int, for app: RunningApp) {
        var policy = policy(for: app)
        policy.idleQuitMinutes = max(1, minutes)
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
    }

    func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try LoginItemManager.setEnabled(isEnabled)
            settings.launchAtLogin = isEnabled
            loginItemStatusDescription = LoginItemManager.statusDescription
            lastEventMessage = isEnabled
                ? "iQuit will start when you sign in."
                : "iQuit will not start when you sign in."
        } catch {
            loginItemStatusDescription = LoginItemManager.statusDescription
            lastEventMessage = "Could not update login item: \(error.localizedDescription)"
        }
    }

    func setProtected(_ isProtected: Bool, for app: RunningApp) {
        var policy = policy(for: app)
        policy.isProtected = isProtected
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
        lastEventMessage = isProtected ? "\(app.displayName) is protected." : "\(app.displayName) can be cleaned up."
    }

    func skip(_ cleanup: PendingCleanup) {
        pendingCleanups.removeAll { $0.id == cleanup.id }
        askPromptController?.dismiss(ifShowing: cleanup)
        startCooldown(bundleID: cleanup.bundleID)
        lastEventMessage = "Skipped \(cleanup.displayName)."
        presentNextPrompt()
    }

    func ignoreApp(_ cleanup: PendingCleanup) {
        var policy = settings.policy(for: cleanup.bundleID, displayName: cleanup.displayName)
        policy.isProtected = true
        policy.displayName = cleanup.displayName
        settings.policies[cleanup.bundleID] = policy

        pendingCleanups
            .filter { $0.bundleID == cleanup.bundleID }
            .forEach { askPromptController?.dismiss(ifShowing: $0) }
        pendingCleanups.removeAll { $0.bundleID == cleanup.bundleID }
        startCooldown(bundleID: cleanup.bundleID)
        lastEventMessage = "\(cleanup.displayName) is ignored."
        presentNextPrompt()
    }

    func approve(_ cleanup: PendingCleanup, as action: CleanupAction? = nil) {
        pendingCleanups.removeAll { $0.id == cleanup.id }
        askPromptController?.dismiss(ifShowing: cleanup)
        let selectedAction = action ?? cleanup.action
        guard selectedAction == .hide || selectedAction == .quit else {
            lastEventMessage = "Pick hide or quit for \(cleanup.displayName)."
            presentNextPrompt()
            return
        }
        perform(
            selectedAction,
            bundleID: cleanup.bundleID,
            displayName: cleanup.displayName,
            preferWindowMinimize: selectedAction == .hide && cleanup.trigger == .visibleWindow
        )
        presentNextPrompt()
    }

    func cleanupNow(_ app: RunningApp, action: CleanupAction) {
        guard action == .hide || action == .quit else { return }
        perform(
            action,
            bundleID: app.bundleID,
            displayName: app.displayName,
            preferWindowMinimize: action == .hide && app.hasVisibleWindows
        )
    }

    func requestAccessibilityAccess() {
        accessibilityTrusted = AccessibilityWindowManager.isTrusted(prompt: true)
        lastEventMessage = accessibilityTrusted
            ? "Accessibility access is enabled."
            : "Grant Accessibility access in System Settings."
    }

    func showOnboarding() {
        isOnboardingPresented = true
    }

    func completeOnboarding() {
        SettingsStore.setOnboardingCompleted(true)
        hasCompletedOnboarding = true
        isOnboardingPresented = false
    }

    func timeout(_ cleanup: PendingCleanup) {
        pendingCleanups.removeAll { $0.id == cleanup.id }
        askPromptController?.dismiss(ifShowing: cleanup)
        startCooldown(bundleID: cleanup.bundleID)
        lastEventMessage = "\(cleanup.displayName) is cooling down."
        presentNextPrompt()
    }

    func idleDescription(for app: RunningApp) -> String {
        if let cooldownText = cooldownDescription(for: app) {
            return cooldownText
        }
        if app.isActive { return "Active now" }
        let seconds = max(0, Int(Date().timeIntervalSince(app.lastActiveAt)))
        if seconds < 60 { return "\(seconds)s idle" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m idle" }
        return "\(minutes / 60)h \(minutes % 60)m idle"
    }

    private func observeWorkspace() {
        let center = workspace.notificationCenter
        center.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    @objc private func workspaceChanged(_: Notification) {
        refreshRunningApplications()
        tick()
    }

    private func tick() {
        accessibilityTrusted = AccessibilityWindowManager.isTrusted()
        loginItemStatusDescription = LoginItemManager.statusDescription
        refreshRunningApplications()
        evaluateIdleApps()
    }

    private func syncLoginItemWithPreference() {
        do {
            try LoginItemManager.setEnabled(settings.launchAtLogin)
            loginItemStatusDescription = LoginItemManager.statusDescription
        } catch {
            loginItemStatusDescription = LoginItemManager.statusDescription
            lastEventMessage = "Could not update login item: \(error.localizedDescription)"
        }
    }

    private func refreshRunningApplications() {
        let now = Date()
        let visibleWindowPIDs = VisibleWindowDetector.visibleWindowProcessIDs()
        let existing = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.bundleID, $0) })
        let apps = workspace.runningApplications.compactMap { app -> RunningApp? in
            guard app.activationPolicy == .regular else { return nil }
            guard let bundleID = app.bundleIdentifier else { return nil }
            guard bundleID != Bundle.main.bundleIdentifier else { return nil }

            let displayName = app.localizedName ?? bundleID
            let previous = existing[bundleID]
            let lastActiveAt = app.isActive ? now : (previous?.lastActiveAt ?? now)
            let hasVisibleWindows = !app.isHidden && visibleWindowPIDs.contains(app.processIdentifier)

            return RunningApp(
                bundleID: bundleID,
                displayName: displayName,
                processIdentifier: app.processIdentifier,
                icon: app.icon,
                isActive: app.isActive,
                hasVisibleWindows: hasVisibleWindows,
                lastActiveAt: lastActiveAt
            )
        }

        runningApps = apps
        let activeBundleIDs = Set(apps.map(\.bundleID))
        pendingCleanups
            .filter { !activeBundleIDs.contains($0.bundleID) }
            .forEach { askPromptController?.dismiss(ifShowing: $0) }
        pendingCleanups.removeAll { pending in
            !activeBundleIDs.contains(pending.bundleID)
        }
        presentNextPrompt()
    }

    private func evaluateIdleApps() {
        guard settings.isEnabled else { return }
        let now = Date()
        removeExpiredCooldowns(now: now)

        for app in runningApps {
            guard cooldowns[app.bundleID] == nil else {
                continue
            }

            let policy = policy(for: app)
            let hasPendingCleanup = pendingCleanups.contains { $0.bundleID == app.bundleID }
            let visibleDecision = decisionEngine.visibleWindowDecision(
                settings: settings,
                policy: policy,
                now: now,
                lastActiveAt: app.lastActiveAt,
                isActive: app.isActive,
                hasVisibleWindows: app.hasVisibleWindows,
                hasPendingCleanup: hasPendingCleanup
            )
            let decision: IdleDecision
            if case .ignore = visibleDecision {
                decision = decisionEngine.idleAppDecision(
                    settings: settings,
                    policy: policy,
                    now: now,
                    lastActiveAt: app.lastActiveAt,
                    isActive: app.isActive,
                    hasVisibleWindows: app.hasVisibleWindows,
                    hasPendingCleanup: hasPendingCleanup
                )
            } else {
                decision = visibleDecision
            }

            switch decision {
            case .ignore:
                continue
            case let .ask(cleanup):
                if !pendingCleanups.contains(where: { $0.id == cleanup.id }) {
                    pendingCleanups.append(cleanup)
                }
                presentNextPrompt()
                let waitingCount = max(0, pendingCleanups.count - 1)
                lastEventMessage = waitingCount == 0
                    ? "\(app.displayName) is idle. Asking what to do."
                    : "\(app.displayName) is idle. \(waitingCount) more waiting."
            case let .perform(action):
                perform(action, bundleID: app.bundleID, displayName: app.displayName)
            }
        }
    }

    private func presentNextPrompt() {
        guard askPromptController?.isShowing != true else { return }
        guard let index = pendingCleanups.indices.first else { return }

        let now = Date()
        var cleanup = pendingCleanups[index]
        cleanup.createdAt = now
        cleanup.dueAt = now.addingTimeInterval(promptDuration)
        pendingCleanups[index] = cleanup

        let icon = runningApps.first { $0.bundleID == cleanup.bundleID }?.icon
        askPromptController?.show(cleanup: cleanup, icon: icon)
    }

    private func perform(
        _ action: CleanupAction,
        bundleID: String,
        displayName: String,
        preferWindowMinimize: Bool = false
    ) {
        guard let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            let removedCleanups = pendingCleanups.filter { $0.bundleID == bundleID }
            removedCleanups.forEach { askPromptController?.dismiss(ifShowing: $0) }
            pendingCleanups.removeAll { $0.bundleID == bundleID }
            presentNextPrompt()
            return
        }

        let succeeded: Bool
        switch action {
        case .hide:
            if preferWindowMinimize {
                let minimizedCount = AccessibilityWindowManager.minimizeVisibleWindows(for: app.processIdentifier)
                accessibilityTrusted = AccessibilityWindowManager.isTrusted()
                succeeded = minimizedCount > 0 || app.hide()
                lastEventMessage = minimizedCount > 0
                    ? "Minimized \(minimizedCount) \(displayName) window\(minimizedCount == 1 ? "" : "s")."
                    : "Window hide unavailable. Hid \(displayName)."
            } else {
                succeeded = app.hide()
            }
        case .quit:
            succeeded = app.terminate()
        case .ask, .off:
            succeeded = false
        }

        startCooldown(bundleID: bundleID)
        touch(bundleID: bundleID)
        if action != .hide || !preferWindowMinimize {
            lastEventMessage = succeeded
                ? "\(action.title) requested for \(displayName)."
                : "Could not \(action.title.lowercased()) \(displayName)."
        }
    }

    private func touch(bundleID: String) {
        guard let index = runningApps.firstIndex(where: { $0.bundleID == bundleID }) else { return }
        runningApps[index].lastActiveAt = Date()
    }

    private func startCooldown(bundleID: String) {
        cooldowns[bundleID] = Date().addingTimeInterval(cooldownDuration)
    }

    private func removeExpiredCooldowns(now: Date) {
        cooldowns = cooldowns.filter { $0.value > now }
    }

    private func cooldownDescription(for app: RunningApp) -> String? {
        guard let until = cooldowns[app.bundleID] else { return nil }
        let seconds = max(0, Int(until.timeIntervalSince(Date())))
        if seconds < 60 { return "Cooling down \(seconds)s" }
        return "Cooling down \(Int(ceil(Double(seconds) / 60.0)))m"
    }
}

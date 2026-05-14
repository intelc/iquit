import AppKit
import Foundation
import iQuitCore

@MainActor
final class AppModel: NSObject, ObservableObject {
    struct UpcomingCleanup: Identifiable {
        var id: String {
            "\(app.bundleID)-\(trigger.rawValue)"
        }

        var app: RunningApp
        var trigger: CleanupTrigger
        var actionDescription: String
        var remainingSeconds: Int
    }

    @Published private(set) var runningApps: [RunningApp] = []
    @Published private(set) var pendingCleanups: [PendingCleanup] = []
    @Published private(set) var lastEventMessage = "Keeping things tidy."
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var isCheckingAccessibility = false
    @Published private(set) var loginItemStatusDescription = LoginItemManager.statusDescription
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published var isOnboardingPresented: Bool
    @Published var settings: AppSettings {
        didSet {
            SettingsStore.save(settings)
            guard oldValue != settings else { return }
            if settings.isEnabled {
                scheduleEvaluation(after: 1)
            } else {
                stopEvaluationTimer()
            }
        }
    }

    private let decisionEngine = IdleDecisionEngine()
    private let workspace = NSWorkspace.shared
    private var askPromptController: AskPromptWindowController?
    private var evaluationTimer: Timer?
    private var accessibilityPollTimer: Timer?
    private var accessibilityPollDeadline: Date?
    private var lastStatusRefresh = Date.distantPast
    private var cooldowns: [String: Date] = [:]
    private let cooldownDuration: TimeInterval = 10 * 60
    private let accessibilityPollDuration: TimeInterval = 5 * 60
    private let promptDuration: TimeInterval = 30
    private let minimumEvaluationInterval: TimeInterval = 10
    private let maximumEvaluationInterval: TimeInterval = 60
    private let statusRefreshInterval: TimeInterval = 5 * 60

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
            onAlwaysHide: { [weak self] cleanup in
                self?.approveAlways(cleanup, as: .hide)
            },
            onAlwaysQuit: { [weak self] cleanup in
                self?.approveAlways(cleanup, as: .quit)
            },
            onIgnore: { [weak self] cleanup in
                self?.ignoreApp(cleanup)
            },
            onSkip: { [weak self] cleanup in
                self?.skip(cleanup)
            },
            onOpen: { [weak self] cleanup in
                self?.open(cleanup)
            },
            onTimeout: { [weak self] cleanup in
                self?.timeout(cleanup)
            }
        )
        observeWorkspace()
        syncLoginItemWithPreference()
        refreshRunningApplications()
        evaluateIdleApps()
        scheduleEvaluation()
    }

    var sortedRunningApps: [RunningApp] {
        runningApps.sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var protectedRunningApps: [RunningApp] {
        sortedRunningApps.filter { policy(for: $0).isProtected }
    }

    var cleanupRunningApps: [RunningApp] {
        sortedRunningApps.filter { !policy(for: $0).isProtected }
    }

    var upcomingCleanups: [UpcomingCleanup] {
        let now = Date()
        return runningApps.compactMap { app in
            guard !app.isActive else { return nil }
            guard cooldowns[app.bundleID] == nil else { return nil }
            let policy = policy(for: app)
            guard !policy.isProtected else { return nil }

            let idleSeconds = max(0, now.timeIntervalSince(app.lastActiveAt))
            let windowRemaining = nextWindowCleanup(
                for: app,
                policy: policy,
                idleSeconds: idleSeconds
            )
            let quitRemaining = nextIdleQuitCleanup(
                for: app,
                policy: policy,
                idleSeconds: idleSeconds
            )

            guard let next = [windowRemaining, quitRemaining].compactMap({ $0 }).min(by: { $0.remainingSeconds < $1.remainingSeconds }) else {
                return nil
            }
            return next
        }
        .sorted { lhs, rhs in
            if lhs.remainingSeconds != rhs.remainingSeconds {
                return lhs.remainingSeconds < rhs.remainingSeconds
            }
            return lhs.app.displayName.localizedCaseInsensitiveCompare(rhs.app.displayName) == .orderedAscending
        }
        .prefix(3)
        .map { $0 }
    }

    var isPaused: Bool {
        !settings.isEnabled
    }

    func policy(for app: RunningApp) -> AppPolicy {
        settings.policy(for: app.bundleID, displayName: app.displayName)
    }

    func setVisibleWindowAction(_ action: AppPolicy.VisibleWindowAction, for app: RunningApp) {
        var policy = policy(for: app)
        policy.visibleWindowAction = action
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
        lastEventMessage = "\(app.displayName) window cleanup: \(action.title)."
    }

    func setIdleQuitAction(_ action: AppPolicy.IdleQuitAction, for app: RunningApp) {
        var policy = policy(for: app)
        policy.idleQuitAction = action
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
        lastEventMessage = "\(app.displayName) idle quit: \(action.title)."
    }

    func setVisibleWindowMinutes(_ minutes: Int, for app: RunningApp) {
        var policy = policy(for: app)
        policy.visibleWindowMinutes = validMinutes(minutes)
        policy.displayName = app.displayName
        settings.policies[app.bundleID] = policy
    }

    func setIdleQuitMinutes(_ minutes: Int, for app: RunningApp) {
        var policy = policy(for: app)
        policy.idleQuitMinutes = validMinutes(minutes)
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

    func approveAlways(_ cleanup: PendingCleanup, as action: CleanupAction) {
        guard action == .hide || action == .quit else { return }
        var policy = settings.policy(for: cleanup.bundleID, displayName: cleanup.displayName)
        let message: String
        if action == .hide {
            guard cleanup.trigger == .visibleWindow else { return }
            policy.visibleWindowAction = .hide
            message = "\(cleanup.displayName) will hide idle windows automatically."
        } else {
            policy.idleQuitAction = .quit
            message = "\(cleanup.displayName) will quit automatically when idle."
        }
        policy.displayName = cleanup.displayName
        settings.policies[cleanup.bundleID] = policy
        approve(cleanup, as: action)
        lastEventMessage = message
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
        if accessibilityTrusted {
            stopAccessibilityPolling()
            lastEventMessage = "Accessibility access is enabled."
        } else {
            startAccessibilityPolling()
            lastEventMessage = "Grant Accessibility access in System Settings."
        }
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

    func open(_ cleanup: PendingCleanup) {
        guard let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == cleanup.bundleID }) else {
            lastEventMessage = "Could not find \(cleanup.displayName)."
            return
        }

        let succeeded = app.activate(options: [.activateAllWindows])
        lastEventMessage = succeeded
            ? "Opened \(cleanup.displayName)."
            : "Could not open \(cleanup.displayName)."
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

    func upcomingDescription(_ upcoming: UpcomingCleanup) -> String {
        if upcoming.remainingSeconds <= 0 {
            return "\(upcoming.actionDescription) now"
        }
        let minutes = Int(ceil(Double(upcoming.remainingSeconds) / 60.0))
        return "\(upcoming.actionDescription) in \(minutes)m"
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
            name: NSWorkspace.didDeactivateApplicationNotification,
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
        center.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didHideApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(workspaceChanged(_:)),
            name: NSWorkspace.didUnhideApplicationNotification,
            object: nil
        )
    }

    private func scheduleEvaluation(after requestedDelay: TimeInterval? = nil) {
        evaluationTimer?.invalidate()
        evaluationTimer = nil

        guard settings.isEnabled else { return }

        let delay = max(0.1, requestedDelay ?? nextEvaluationInterval())
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = min(15, max(1, delay * 0.1))
        RunLoop.main.add(timer, forMode: .common)
        evaluationTimer = timer
    }

    private func stopEvaluationTimer() {
        evaluationTimer?.invalidate()
        evaluationTimer = nil
    }

    private func startAccessibilityPolling() {
        accessibilityPollDeadline = Date().addingTimeInterval(accessibilityPollDuration)
        isCheckingAccessibility = true
        accessibilityPollTimer?.invalidate()

        let pollTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollAccessibilityAccess()
            }
        }
        RunLoop.main.add(pollTimer, forMode: .common)
        accessibilityPollTimer = pollTimer
    }

    private func pollAccessibilityAccess() {
        accessibilityTrusted = AccessibilityWindowManager.isTrusted()
        if accessibilityTrusted {
            stopAccessibilityPolling()
            lastEventMessage = "Accessibility access is enabled."
            return
        }

        if let accessibilityPollDeadline, Date() >= accessibilityPollDeadline {
            stopAccessibilityPolling()
            lastEventMessage = "Still waiting for Accessibility access."
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        accessibilityPollDeadline = nil
        isCheckingAccessibility = false
    }

    @objc private func workspaceChanged(_: Notification) {
        tick()
    }

    private func tick() {
        let now = Date()
        refreshStatusIfNeeded(now: now)
        refreshRunningApplications(now: now)
        evaluateIdleApps(now: now)
        scheduleEvaluation()
    }

    private func refreshStatusIfNeeded(now: Date, force: Bool = false) {
        guard force || now.timeIntervalSince(lastStatusRefresh) >= statusRefreshInterval else { return }
        accessibilityTrusted = AccessibilityWindowManager.isTrusted()
        loginItemStatusDescription = LoginItemManager.statusDescription
        lastStatusRefresh = now
    }

    private func syncLoginItemWithPreference() {
        do {
            try LoginItemManager.setEnabled(settings.launchAtLogin)
            loginItemStatusDescription = LoginItemManager.statusDescription
            lastStatusRefresh = Date()
        } catch {
            loginItemStatusDescription = LoginItemManager.statusDescription
            lastStatusRefresh = Date()
            lastEventMessage = "Could not update login item: \(error.localizedDescription)"
        }
    }

    private func refreshRunningApplications(now: Date = Date()) {
        let visibleWindowPIDs = VisibleWindowDetector.visibleWindowProcessIDs()
        let existing = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.bundleID, $0) })
        let apps = workspace.runningApplications.compactMap { app -> RunningApp? in
            guard app.activationPolicy == .regular else { return nil }
            guard let bundleID = app.bundleIdentifier else { return nil }
            guard bundleID != Bundle.main.bundleIdentifier else { return nil }

            let displayName = app.localizedName ?? bundleID
            let previous = existing[bundleID]
            let lastActiveAt: Date
            if app.isActive {
                lastActiveAt = previous?.lastActiveAt ?? now
            } else if previous?.isActive == true {
                lastActiveAt = now
            } else {
                lastActiveAt = previous?.lastActiveAt ?? now
            }
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

        if runningApps != apps {
            runningApps = apps
        }
        let activeBundleIDs = Set(apps.map(\.bundleID))
        pendingCleanups
            .filter { !activeBundleIDs.contains($0.bundleID) }
            .forEach { askPromptController?.dismiss(ifShowing: $0) }
        pendingCleanups.removeAll { pending in
            !activeBundleIDs.contains(pending.bundleID)
        }
        presentNextPrompt()
    }

    private func evaluateIdleApps(now: Date = Date()) {
        guard settings.isEnabled else { return }
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
            let decisionTrigger: CleanupTrigger
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
                decisionTrigger = .idleApp
            } else {
                decision = visibleDecision
                decisionTrigger = .visibleWindow
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
                perform(
                    action,
                    bundleID: app.bundleID,
                    displayName: app.displayName,
                    preferWindowMinimize: action == .hide && decisionTrigger == .visibleWindow
                )
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

        let app = runningApps.first { $0.bundleID == cleanup.bundleID }
        askPromptController?.show(cleanup: cleanup, icon: app?.icon, idleSince: app?.lastActiveAt)
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

    private func nextEvaluationInterval(now: Date = Date()) -> TimeInterval {
        removeExpiredCooldowns(now: now)

        var soonest = maximumEvaluationInterval
        for cooldownExpiry in cooldowns.values {
            soonest = min(soonest, max(0, cooldownExpiry.timeIntervalSince(now)))
        }

        for app in runningApps {
            guard !app.isActive else { continue }
            guard !pendingCleanups.contains(where: { $0.bundleID == app.bundleID }) else { continue }

            let policy = policy(for: app)
            guard !policy.isProtected else { continue }

            let idleSeconds = max(0, now.timeIntervalSince(app.lastActiveAt))
            if app.hasVisibleWindows, policy.visibleWindowAction != .off {
                let remaining = TimeInterval(policy.visibleWindowMinutes * 60) - idleSeconds
                soonest = min(soonest, max(0, remaining))
            } else if !app.hasVisibleWindows, policy.idleQuitAction != .off {
                let remaining = TimeInterval(policy.idleQuitMinutes * 60) - idleSeconds
                soonest = min(soonest, max(0, remaining))
            }
        }

        if soonest <= minimumEvaluationInterval {
            return max(1, soonest)
        }
        return min(maximumEvaluationInterval, soonest)
    }

    private func cooldownDescription(for app: RunningApp) -> String? {
        guard let until = cooldowns[app.bundleID] else { return nil }
        let seconds = max(0, Int(until.timeIntervalSince(Date())))
        if seconds < 60 { return "Cooling down \(seconds)s" }
        return "Cooling down \(Int(ceil(Double(seconds) / 60.0)))m"
    }

    private func nextWindowCleanup(
        for app: RunningApp,
        policy: AppPolicy,
        idleSeconds: TimeInterval
    ) -> UpcomingCleanup? {
        guard app.hasVisibleWindows else { return nil }
        guard policy.visibleWindowAction != .off else { return nil }
        let remaining = max(0, Int(ceil(TimeInterval(policy.visibleWindowMinutes * 60) - idleSeconds)))
        let action = policy.visibleWindowAction == .hide ? "Always hide" : "Ask windows"
        return UpcomingCleanup(
            app: app,
            trigger: .visibleWindow,
            actionDescription: action,
            remainingSeconds: remaining
        )
    }

    private func nextIdleQuitCleanup(
        for app: RunningApp,
        policy: AppPolicy,
        idleSeconds: TimeInterval
    ) -> UpcomingCleanup? {
        guard !app.hasVisibleWindows else { return nil }
        guard policy.idleQuitAction != .off else { return nil }
        let remaining = max(0, Int(ceil(TimeInterval(policy.idleQuitMinutes * 60) - idleSeconds)))
        let action = policy.idleQuitAction == .quit ? "Always quit" : "Ask to quit"
        return UpcomingCleanup(
            app: app,
            trigger: .idleApp,
            actionDescription: action,
            remainingSeconds: remaining
        )
    }

    private func validMinutes(_ minutes: Int) -> Int {
        min(119, max(1, minutes))
    }

}

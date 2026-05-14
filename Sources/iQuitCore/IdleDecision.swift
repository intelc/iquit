import Foundation

public enum IdleDecision: Equatable, Sendable {
    case ignore(String)
    case ask(PendingCleanup)
    case perform(CleanupAction)
}

public struct IdleDecisionEngine: Sendable {
    public init() {}

    public func visibleWindowDecision(
        settings: AppSettings,
        policy: AppPolicy,
        now: Date,
        lastActiveAt: Date,
        isActive: Bool,
        hasVisibleWindows: Bool,
        hasPendingCleanup: Bool
    ) -> IdleDecision {
        guard settings.isEnabled else { return .ignore("iQuit is paused") }
        guard !isActive else { return .ignore("App is active") }
        guard !policy.isProtected else { return .ignore("App is protected") }
        guard policy.visibleWindowAction != .off else { return .ignore("Visible window cleanup is off") }
        guard hasVisibleWindows else { return .ignore("No visible windows") }
        guard !hasPendingCleanup else { return .ignore("Cleanup is pending") }

        let idleSeconds = now.timeIntervalSince(lastActiveAt)
        let threshold = TimeInterval(policy.visibleWindowMinutes * 60)
        guard idleSeconds >= threshold else { return .ignore("Below idle threshold") }

        if policy.visibleWindowAction.isAutomatic {
            return .perform(policy.visibleWindowAction)
        }

        return .ask(PendingCleanup(
            bundleID: policy.bundleID,
            displayName: policy.displayName,
            action: .ask,
            trigger: .visibleWindow,
            dueAt: now.addingTimeInterval(30),
            createdAt: now
        ))
    }

    public func idleAppDecision(
        settings: AppSettings,
        policy: AppPolicy,
        now: Date,
        lastActiveAt: Date,
        isActive: Bool,
        hasVisibleWindows: Bool,
        hasPendingCleanup: Bool
    ) -> IdleDecision {
        guard settings.isEnabled else { return .ignore("iQuit is paused") }
        guard !isActive else { return .ignore("App is active") }
        guard !policy.isProtected else { return .ignore("App is protected") }
        guard policy.idleQuitAction != .off else { return .ignore("Idle quit is off") }
        guard !hasVisibleWindows else { return .ignore("Visible window cleanup owns this") }
        guard !hasPendingCleanup else { return .ignore("Cleanup is pending") }

        let idleSeconds = now.timeIntervalSince(lastActiveAt)
        let threshold = TimeInterval(policy.idleQuitMinutes * 60)
        guard idleSeconds >= threshold else { return .ignore("Below idle quit threshold") }

        if policy.idleQuitAction == .quit {
            return .perform(.quit)
        }

        return .ask(PendingCleanup(
            bundleID: policy.bundleID,
            displayName: policy.displayName,
            action: .quit,
            trigger: .idleApp,
            dueAt: now.addingTimeInterval(30),
            createdAt: now
        ))
    }
}

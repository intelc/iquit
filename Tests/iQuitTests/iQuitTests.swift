import Foundation
@testable import iQuitCore
import Testing

@Test func appSettingsLaunchAtLoginDefaultsToOn() throws {
    let settings = AppSettings()
    #expect(settings.launchAtLogin)

    let legacyJSON = #"{"isEnabled":true,"defaultVisibleWindowMinutes":20,"defaultIdleQuitMinutes":60,"reviewBeforeCleanup":true,"reviewDelaySeconds":60,"policies":{}}"#
    let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))
    #expect(decoded.launchAtLogin)
}

@Test func appPolicyMigratesEnabledRulesToAskMode() throws {
    let legacyJSON = #"{"bundleID":"com.example.mail","displayName":"Mail","visibleWindowCleanupEnabled":true,"idleQuitEnabled":true,"visibleWindowMinutes":20,"idleQuitMinutes":60,"isProtected":false}"#
    let policy = try JSONDecoder().decode(AppPolicy.self, from: Data(legacyJSON.utf8))

    #expect(policy.visibleWindowAction == .ask)
    #expect(policy.idleQuitAction == .ask)
}

@Test func visibleWindowDecisionIgnoresActiveApps() {
    let engine = IdleDecisionEngine()
    let now = Date()
    let policy = AppPolicy(bundleID: "com.example.mail", displayName: "Mail", visibleWindowMinutes: 5)

    let decision = engine.visibleWindowDecision(
        settings: AppSettings(),
        policy: policy,
        now: now,
        lastActiveAt: now.addingTimeInterval(-600),
        isActive: true,
        hasVisibleWindows: true,
        hasPendingCleanup: false
    )

    #expect(decision == .ignore("App is active"))
}

@Test func visibleWindowDecisionOffersHideOrQuit() {
    let engine = IdleDecisionEngine()
    let now = Date()
    let policy = AppPolicy(bundleID: "com.example.word", displayName: "Word", visibleWindowMinutes: 5)

    let decision = engine.visibleWindowDecision(
        settings: AppSettings(),
        policy: policy,
        now: now,
        lastActiveAt: now.addingTimeInterval(-600),
        isActive: false,
        hasVisibleWindows: true,
        hasPendingCleanup: false
    )

    guard case let .ask(cleanup) = decision else {
        Issue.record("Expected pending cleanup")
        return
    }

    #expect(cleanup.bundleID == "com.example.word")
    #expect(cleanup.action == CleanupAction.ask)
    #expect(cleanup.trigger == CleanupTrigger.visibleWindow)
}

@Test func visibleWindowDecisionPerformsAutomaticHide() {
    let engine = IdleDecisionEngine()
    let now = Date()
    let policy = AppPolicy(
        bundleID: "com.example.word",
        displayName: "Word",
        visibleWindowAction: .hide,
        visibleWindowMinutes: 5
    )

    let decision = engine.visibleWindowDecision(
        settings: AppSettings(),
        policy: policy,
        now: now,
        lastActiveAt: now.addingTimeInterval(-600),
        isActive: false,
        hasVisibleWindows: true,
        hasPendingCleanup: false
    )

    #expect(decision == .perform(.hide))
}

@Test func idleAppDecisionOffersQuitOnlyWhenHiddenOrWindowless() {
    let engine = IdleDecisionEngine()
    let now = Date()
    let policy = AppPolicy(bundleID: "com.example.preview", displayName: "Preview", idleQuitMinutes: 5)

    let decision = engine.idleAppDecision(
        settings: AppSettings(),
        policy: policy,
        now: now,
        lastActiveAt: now.addingTimeInterval(-600),
        isActive: false,
        hasVisibleWindows: false,
        hasPendingCleanup: false
    )

    guard case let .ask(cleanup) = decision else {
        Issue.record("Expected pending cleanup")
        return
    }

    #expect(cleanup.action == CleanupAction.quit)
    #expect(cleanup.trigger == CleanupTrigger.idleApp)
}

@Test func idleAppDecisionPerformsAutomaticQuit() {
    let engine = IdleDecisionEngine()
    let now = Date()
    let policy = AppPolicy(
        bundleID: "com.example.preview",
        displayName: "Preview",
        idleQuitAction: .quit,
        idleQuitMinutes: 5
    )

    let decision = engine.idleAppDecision(
        settings: AppSettings(),
        policy: policy,
        now: now,
        lastActiveAt: now.addingTimeInterval(-600),
        isActive: false,
        hasVisibleWindows: false,
        hasPendingCleanup: false
    )

    #expect(decision == .perform(.quit))
}

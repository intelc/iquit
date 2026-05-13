import Foundation

public enum CleanupTrigger: String, Codable, Equatable, Sendable {
    case visibleWindow
    case idleApp

    public var titleSuffix: String {
        switch self {
        case .visibleWindow: "window is idle"
        case .idleApp: "is idle"
        }
    }

    public var subtitle: String {
        switch self {
        case .visibleWindow: "Hide or quit it?"
        case .idleApp: "Quit it?"
        }
    }
}

public struct PendingCleanup: Identifiable, Equatable, Sendable {
    public var id: String {
        "\(bundleID)-\(trigger.rawValue)"
    }

    public var bundleID: String
    public var displayName: String
    public var action: CleanupAction
    public var trigger: CleanupTrigger
    public var dueAt: Date
    public var createdAt: Date

    public init(
        bundleID: String,
        displayName: String,
        action: CleanupAction,
        trigger: CleanupTrigger = .visibleWindow,
        dueAt: Date,
        createdAt: Date = Date()
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.action = action
        self.trigger = trigger
        self.dueAt = dueAt
        self.createdAt = createdAt
    }
}

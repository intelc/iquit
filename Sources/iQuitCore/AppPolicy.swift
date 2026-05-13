import Foundation

public struct AppPolicy: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        bundleID
    }

    public var bundleID: String
    public var displayName: String
    public var visibleWindowCleanupEnabled: Bool
    public var idleQuitEnabled: Bool
    public var visibleWindowMinutes: Int
    public var idleQuitMinutes: Int
    public var isProtected: Bool

    public init(
        bundleID: String,
        displayName: String,
        visibleWindowCleanupEnabled: Bool = true,
        idleQuitEnabled: Bool = true,
        visibleWindowMinutes: Int = 20,
        idleQuitMinutes: Int = 60,
        isProtected: Bool = false
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.visibleWindowCleanupEnabled = visibleWindowCleanupEnabled
        self.idleQuitEnabled = idleQuitEnabled
        self.visibleWindowMinutes = max(1, visibleWindowMinutes)
        self.idleQuitMinutes = max(1, idleQuitMinutes)
        self.isProtected = isProtected
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID
        case displayName
        case action
        case idleMinutes
        case visibleWindowCleanupEnabled
        case idleQuitEnabled
        case visibleWindowMinutes
        case idleQuitMinutes
        case isProtected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        displayName = try container.decode(String.self, forKey: .displayName)
        let oldAction = try container.decodeIfPresent(CleanupAction.self, forKey: .action)
        let oldIdleMinutes = try container.decodeIfPresent(Int.self, forKey: .idleMinutes)
        visibleWindowCleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .visibleWindowCleanupEnabled) ?? (oldAction != .off)
        idleQuitEnabled = try container.decodeIfPresent(Bool.self, forKey: .idleQuitEnabled) ?? true
        visibleWindowMinutes = try max(1, container.decodeIfPresent(Int.self, forKey: .visibleWindowMinutes) ?? oldIdleMinutes ?? 20)
        idleQuitMinutes = try max(1, container.decodeIfPresent(Int.self, forKey: .idleQuitMinutes) ?? 60)
        isProtected = try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(visibleWindowCleanupEnabled, forKey: .visibleWindowCleanupEnabled)
        try container.encode(idleQuitEnabled, forKey: .idleQuitEnabled)
        try container.encode(visibleWindowMinutes, forKey: .visibleWindowMinutes)
        try container.encode(idleQuitMinutes, forKey: .idleQuitMinutes)
        try container.encode(isProtected, forKey: .isProtected)
    }
}

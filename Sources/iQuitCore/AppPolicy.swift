import Foundation

public struct AppPolicy: Codable, Equatable, Identifiable, Sendable {
    private static func validMinutes(_ minutes: Int) -> Int {
        min(119, max(1, minutes))
    }

    public var id: String {
        bundleID
    }

    public enum VisibleWindowAction: String, CaseIterable, Codable, Identifiable, Sendable {
        case ask
        case hide
        case off

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .ask: "Ask"
            case .hide: "Always Hide"
            case .off: "Off"
            }
        }
    }

    public enum IdleQuitAction: String, CaseIterable, Codable, Identifiable, Sendable {
        case ask
        case quit
        case off

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .ask: "Ask"
            case .quit: "Always Quit"
            case .off: "Never"
            }
        }
    }

    public var bundleID: String
    public var displayName: String
    public var visibleWindowAction: VisibleWindowAction
    public var idleQuitAction: IdleQuitAction
    public var visibleWindowMinutes: Int
    public var idleQuitMinutes: Int
    public var isProtected: Bool

    public var visibleWindowCleanupEnabled: Bool {
        get { visibleWindowAction != .off }
        set {
            if newValue {
                if visibleWindowAction == .off {
                    visibleWindowAction = .ask
                }
            } else {
                visibleWindowAction = .off
            }
        }
    }

    public var idleQuitEnabled: Bool {
        get { idleQuitAction != .off }
        set {
            if newValue {
                if idleQuitAction == .off {
                    idleQuitAction = .ask
                }
            } else {
                idleQuitAction = .off
            }
        }
    }

    public init(
        bundleID: String,
        displayName: String,
        visibleWindowAction: VisibleWindowAction? = nil,
        idleQuitAction: IdleQuitAction? = nil,
        visibleWindowCleanupEnabled: Bool = true,
        idleQuitEnabled: Bool = true,
        visibleWindowMinutes: Int = 20,
        idleQuitMinutes: Int = 60,
        isProtected: Bool = false
    ) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.visibleWindowAction = visibleWindowAction ?? (visibleWindowCleanupEnabled ? .ask : .off)
        self.idleQuitAction = idleQuitAction ?? (idleQuitEnabled ? .ask : .off)
        self.visibleWindowMinutes = Self.validMinutes(visibleWindowMinutes)
        self.idleQuitMinutes = Self.validMinutes(idleQuitMinutes)
        self.isProtected = isProtected
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID
        case displayName
        case action
        case idleMinutes
        case visibleWindowAction
        case idleQuitAction
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
        let oldVisibleWindowEnabled = try container.decodeIfPresent(Bool.self, forKey: .visibleWindowCleanupEnabled) ?? (oldAction != .off)
        let oldIdleQuitEnabled = try container.decodeIfPresent(Bool.self, forKey: .idleQuitEnabled) ?? true
        let legacyVisibleWindowAction = try? container.decodeIfPresent(CleanupAction.self, forKey: .visibleWindowAction)
        if let decodedVisibleWindowAction = try? container.decodeIfPresent(VisibleWindowAction.self, forKey: .visibleWindowAction) {
            visibleWindowAction = decodedVisibleWindowAction
        } else if let decodedLegacyAction = legacyVisibleWindowAction {
            visibleWindowAction = decodedLegacyAction == .off ? .off : decodedLegacyAction == .hide ? .hide : .ask
        } else {
            visibleWindowAction = oldVisibleWindowEnabled ? .ask : .off
        }
        idleQuitAction = try container.decodeIfPresent(IdleQuitAction.self, forKey: .idleQuitAction)
            ?? (legacyVisibleWindowAction == .quit ? .quit : oldIdleQuitEnabled ? .ask : .off)
        visibleWindowMinutes = try Self.validMinutes(container.decodeIfPresent(Int.self, forKey: .visibleWindowMinutes) ?? oldIdleMinutes ?? 20)
        idleQuitMinutes = try Self.validMinutes(container.decodeIfPresent(Int.self, forKey: .idleQuitMinutes) ?? 60)
        isProtected = try container.decodeIfPresent(Bool.self, forKey: .isProtected) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bundleID, forKey: .bundleID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(visibleWindowAction, forKey: .visibleWindowAction)
        try container.encode(idleQuitAction, forKey: .idleQuitAction)
        try container.encode(visibleWindowCleanupEnabled, forKey: .visibleWindowCleanupEnabled)
        try container.encode(idleQuitEnabled, forKey: .idleQuitEnabled)
        try container.encode(visibleWindowMinutes, forKey: .visibleWindowMinutes)
        try container.encode(idleQuitMinutes, forKey: .idleQuitMinutes)
        try container.encode(isProtected, forKey: .isProtected)
    }
}

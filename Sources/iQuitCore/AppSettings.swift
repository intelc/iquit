import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    private static func validMinutes(_ minutes: Int) -> Int {
        min(119, max(1, minutes))
    }

    public var isEnabled: Bool
    public var defaultVisibleWindowMinutes: Int
    public var defaultIdleQuitMinutes: Int
    public var launchAtLogin: Bool
    public var reviewBeforeCleanup: Bool
    public var reviewDelaySeconds: Int
    public var policies: [String: AppPolicy]

    public init(
        isEnabled: Bool = true,
        defaultVisibleWindowMinutes: Int = 20,
        defaultIdleQuitMinutes: Int = 60,
        launchAtLogin: Bool = true,
        reviewBeforeCleanup: Bool = true,
        reviewDelaySeconds: Int = 60,
        policies: [String: AppPolicy] = [:]
    ) {
        self.isEnabled = isEnabled
        self.defaultVisibleWindowMinutes = Self.validMinutes(defaultVisibleWindowMinutes)
        self.defaultIdleQuitMinutes = Self.validMinutes(defaultIdleQuitMinutes)
        self.launchAtLogin = launchAtLogin
        self.reviewBeforeCleanup = reviewBeforeCleanup
        self.reviewDelaySeconds = max(5, reviewDelaySeconds)
        self.policies = policies
    }

    public func policy(for bundleID: String, displayName: String) -> AppPolicy {
        policies[bundleID] ?? AppPolicy(
            bundleID: bundleID,
            displayName: displayName,
            visibleWindowMinutes: defaultVisibleWindowMinutes,
            idleQuitMinutes: defaultIdleQuitMinutes
        )
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case defaultIdleMinutes
        case defaultVisibleWindowMinutes
        case defaultIdleQuitMinutes
        case launchAtLogin
        case reviewBeforeCleanup
        case reviewDelaySeconds
        case policies
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let oldDefaultIdleMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultIdleMinutes)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        defaultVisibleWindowMinutes = try Self.validMinutes(container.decodeIfPresent(Int.self, forKey: .defaultVisibleWindowMinutes) ?? oldDefaultIdleMinutes ?? 20)
        defaultIdleQuitMinutes = try Self.validMinutes(container.decodeIfPresent(Int.self, forKey: .defaultIdleQuitMinutes) ?? 60)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        reviewBeforeCleanup = try container.decodeIfPresent(Bool.self, forKey: .reviewBeforeCleanup) ?? true
        reviewDelaySeconds = try max(5, container.decodeIfPresent(Int.self, forKey: .reviewDelaySeconds) ?? 60)
        policies = try container.decodeIfPresent([String: AppPolicy].self, forKey: .policies) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(defaultVisibleWindowMinutes, forKey: .defaultVisibleWindowMinutes)
        try container.encode(defaultIdleQuitMinutes, forKey: .defaultIdleQuitMinutes)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(reviewBeforeCleanup, forKey: .reviewBeforeCleanup)
        try container.encode(reviewDelaySeconds, forKey: .reviewDelaySeconds)
        try container.encode(policies, forKey: .policies)
    }
}

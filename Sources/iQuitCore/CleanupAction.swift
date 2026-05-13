import Foundation

public enum CleanupAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case ask
    case hide
    case quit
    case off

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .ask: "Ask"
        case .hide: "Hide"
        case .quit: "Quit"
        case .off: "Off"
        }
    }

    public var isAutomatic: Bool {
        switch self {
        case .hide, .quit: true
        case .ask, .off: false
        }
    }
}

import AppKit
import Foundation

struct RunningApp: Identifiable, Equatable {
    var id: String {
        bundleID
    }

    var bundleID: String
    var displayName: String
    var processIdentifier: pid_t
    var icon: NSImage?
    var isActive: Bool
    var hasVisibleWindows: Bool
    var lastActiveAt: Date

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.bundleID == rhs.bundleID
            && lhs.displayName == rhs.displayName
            && lhs.processIdentifier == rhs.processIdentifier
            && lhs.isActive == rhs.isActive
            && lhs.hasVisibleWindows == rhs.hasVisibleWindows
            && lhs.lastActiveAt == rhs.lastActiveAt
    }
}

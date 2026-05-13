import CoreGraphics
import Foundation

enum VisibleWindowDetector {
    static func visibleWindowProcessIDs() -> Set<pid_t> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return Set(windows.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0 else { return nil }
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t else { return nil }
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            guard width >= 24, height >= 24 else { return nil }
            return pid
        })
    }
}

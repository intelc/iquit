import ApplicationServices
import Foundation

@MainActor
enum AccessibilityWindowManager {
    static func isTrusted(prompt: Bool = false) -> Bool {
        guard prompt else {
            return AXIsProcessTrusted() || canReadFocusedApplication()
        }

        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func minimizeVisibleWindows(for processIdentifier: pid_t) -> Int {
        guard isTrusted() else { return 0 }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var windowsValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard copyResult == .success, let windows = windowsValue as? [AXUIElement] else {
            return 0
        }

        return windows.reduce(0) { count, window in
            count + (minimize(window) ? 1 : 0)
        }
    }

    private static func canReadFocusedApplication() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApplication: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApplication
        )
        return result == .success && focusedApplication != nil
    }

    private static func minimize(_ window: AXUIElement) -> Bool {
        if isWindowMinimized(window) {
            return false
        }

        let setResult = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        if setResult == .success {
            return true
        }

        var buttonValue: CFTypeRef?
        let copyButtonResult = AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &buttonValue)
        guard copyButtonResult == .success, let button = buttonValue else {
            return false
        }

        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    private static func isWindowMinimized(_ window: AXUIElement) -> Bool {
        var minimizedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue)
        guard result == .success, let minimizedValue else { return false }
        guard CFGetTypeID(minimizedValue) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((minimizedValue as! CFBoolean))
    }
}

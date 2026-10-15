import AppKit

public enum TargetActivator {
    public static let timeout: Duration = .seconds(1)
    public static let pollInterval: Duration = .milliseconds(20)

    @MainActor
    public static func activate(_ target: NSRunningApplication) async -> Bool {
        if target.isActive { return true }
        NSApp.yieldActivation(to: target)
        target.activate(options: [])
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if target.isActive { return true }
            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                return false
            }
        }
        return target.isActive
    }
}

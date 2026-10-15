import AppKit

@MainActor
public final class FrontmostAppTracker: NSObject {
    public private(set) var lastExternalApp: NSRunningApplication?

    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

    public init(workspace: NSWorkspace = .shared) {
        super.init()
        if let frontmost = workspace.frontmostApplication, frontmost.processIdentifier != ownProcessIdentifier {
            lastExternalApp = frontmost
        }
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(didActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: workspace
        )
    }

    public var lastExternalBundleID: String? {
        lastExternalApp?.bundleIdentifier
    }

    @objc private func didActivateApplication(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        noteActivated(app)
    }

    func noteActivated(_ app: NSRunningApplication) {
        guard app.processIdentifier != ownProcessIdentifier else { return }
        lastExternalApp = app
    }
}

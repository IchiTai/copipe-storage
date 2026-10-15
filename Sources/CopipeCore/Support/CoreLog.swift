import os

enum CoreLog {
    static let store = Logger(subsystem: AppIdentity.bundleIdentifier, category: "store")
    static let capture = Logger(subsystem: AppIdentity.bundleIdentifier, category: "capture")
}

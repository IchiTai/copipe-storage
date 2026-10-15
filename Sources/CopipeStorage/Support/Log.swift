import CopipeCore
import os

enum Log {
    static let app = Logger(subsystem: AppIdentity.bundleIdentifier, category: "app")
}

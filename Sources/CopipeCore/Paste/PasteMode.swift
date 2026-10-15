public enum PasteMode: Sendable, Equatable {
    case full
    case plainText
    case copyOnly
}

public enum CopyOnlyReason: Sendable, Equatable {
    case requested
    case noPostEventPermission
    case targetTerminated
    case activationTimedOut
}

public enum PasteOutcome: Sendable, Equatable {
    case pasted
    case copiedOnly(CopyOnlyReason)
    case failed
}

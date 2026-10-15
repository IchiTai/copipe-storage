import CopipeCore
import Foundation
import Observation

@Observable
final class AppSettings {
    static let maxClipsKey = "maxClips"

    var maxClips: Int {
        didSet {
            let clamped = Limits(maxClips: maxClips).maxClips
            if clamped != maxClips {
                maxClips = clamped
                return
            }
            defaults.set(maxClips, forKey: Self.maxClipsKey)
            onLimitsChange?(limits)
        }
    }
    var onLimitsChange: ((Limits) -> Void)?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.maxClipsKey) as? Int
        maxClips = Limits(maxClips: stored ?? Limits.defaultCount).maxClips
    }

    var limits: Limits {
        Limits(maxClips: maxClips)
    }
}

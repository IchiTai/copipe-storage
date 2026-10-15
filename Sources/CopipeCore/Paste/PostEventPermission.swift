import ApplicationServices
import CoreGraphics

public enum PostEventPermission {
    // システム設定の「アクセシビリティ」は PostEvent と Accessibility の 2 つの TCC サービスを
    // まとめて表示する。どちらの付与でも ⌘V の送出は通るため、両方を見る
    public static var isGranted: Bool {
        CGPreflightPostEventAccess() || AXIsProcessTrusted()
    }

    public static var postEventGranted: Bool {
        CGPreflightPostEventAccess()
    }

    public static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    public static func request() -> Bool {
        CGRequestPostEventAccess()
    }
}

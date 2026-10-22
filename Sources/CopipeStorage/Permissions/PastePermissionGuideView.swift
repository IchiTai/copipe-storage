import SwiftUI

struct PastePermissionGuideView: View {
    enum Reason {
        case noPermission
        case copiedOnly
        case readDenied
        case pasteFailed

        var titleKey: String {
            switch self {
            case .noPermission: "guide.permission.title"
            case .copiedOnly: "guide.copied.title"
            case .readDenied: "guide.read_denied.title"
            case .pasteFailed: "guide.paste_failed.title"
            }
        }

        var bodyKey: String {
            switch self {
            case .noPermission: "guide.permission.body"
            case .copiedOnly: "guide.copied.body"
            case .readDenied: "guide.read_denied.body"
            case .pasteFailed: "guide.paste_failed.body"
            }
        }

        var opensSettings: Bool {
            self == .noPermission || self == .readDenied
        }
    }

    let reason: Reason
    let openSettings: () -> Void
    let close: () -> Void

    // この窓は key にならない（貼り先のキー入力を奪わないため）ので、ボタンにキー割り当ては付けない
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string(reason.titleKey))
                .font(.system(size: 14, weight: .semibold))
            Text(L10n.string(reason.bodyKey))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L10n.string("guide.close"), action: close)
                if reason.opensSettings {
                    Button(L10n.string("guide.open_settings"), action: openSettings)
                        .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)
        }
        .padding(16)
        .frame(width: 380)
    }
}

import AppKit
import CopipeCore
import SwiftUI

struct ClipRowView: View {
    static let quickKeyColumnWidth: CGFloat = 28

    let primaryText: String
    let timeLabel: String
    let icon: NSImage?
    let thumbnail: NSImage?
    let index: Int
    let isSelected: Bool
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryText)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text(timeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Text(index < KeyCommand.quickKeyCount ? "⌘\(index + 1)" : "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(isSelected ? .primary : .tertiary)
                .frame(width: Self.quickKeyColumnWidth, alignment: .trailing)
            CopyButton(action: onCopy)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    private var backgroundColor: Color {
        if isSelected { return Color.accentColor.opacity(0.22) }
        if isHovered { return Color.primary.opacity(0.07) }
        return .clear
    }
}

struct CopyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(L10n.string("panel.copy"))
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .help(L10n.string("panel.copy"))
    }
}

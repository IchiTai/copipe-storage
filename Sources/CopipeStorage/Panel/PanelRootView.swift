import AppKit
import CopipeCore
import SwiftUI

struct PanelRootView: View {
    @Bindable var model: PanelViewModel
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.string("panel.filter.placeholder"), text: $model.filterText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($filterFocused)
                Button {
                    model.openMenu()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.string("panel.menu"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            Divider()
            if model.filteredClips.isEmpty {
                Spacer()
                Text(L10n.string(model.clips.isEmpty ? "panel.empty" : "panel.no_match"))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(model.filteredClips.enumerated()), id: \.element.id) { index, clip in
                                ClipRowView(
                                    primaryText: model.primaryText(for: clip),
                                    timeLabel: model.timeLabel(for: clip),
                                    icon: model.icon(for: clip),
                                    thumbnail: model.thumbnail(for: clip),
                                    index: index,
                                    isSelected: clip.id == model.selectedID,
                                    onCopy: { model.activate(id: clip.id, mode: .copyOnly) }
                                )
                                .id(clip.id)
                                .onTapGesture {
                                    model.activate(id: clip.id, mode: KeyCommand.mode(for: NSEvent.modifierFlags))
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: model.selectedID) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
                Divider()
                PanelFooterView()
            }
        }
        .onAppear { filterFocused = true }
        .onChange(of: model.focusRequestCount) { _, _ in filterFocused = true }
        .onKeyPress(phases: .down) { press in
            KeyCommand.handle(press, model: model)
        }
    }
}

struct PanelFooterView: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(KeyCommand.hints, id: \.labelKey) { hint in
                HStack(spacing: 4) {
                    Text(hint.symbols)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
                    Text(L10n.string(hint.labelKey))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(hint.spokenLabel)
            }
            Spacer()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

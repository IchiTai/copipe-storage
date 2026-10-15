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
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(L10n.string("panel.menu"))
            }
            .padding(12)
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
            }
        }
        .onAppear { filterFocused = true }
        .onChange(of: model.focusRequestCount) { _, _ in filterFocused = true }
        .onKeyPress(phases: .down) { press in
            KeyCommand.handle(press, model: model)
        }
    }
}

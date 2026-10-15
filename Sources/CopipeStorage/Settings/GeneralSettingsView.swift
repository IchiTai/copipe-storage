import CopipeCore
import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLogin

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder(L10n.string("settings.shortcut"), name: .togglePanel)
            Section {
                Toggle(L10n.string("settings.launch_at_login"), isOn: $launchAtLogin.isEnabled)
                if launchAtLogin.requiresApproval {
                    HStack {
                        Text(L10n.string("settings.launch_at_login.requires_approval"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button(L10n.string("settings.open_login_items")) { launchAtLogin.openLoginItemsSettings() }
                    }
                }
                if let error = launchAtLogin.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                Text(L10n.string("settings.launch_at_login.note"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Stepper(value: $settings.maxClips, in: Limits.countRange, step: 100) {
                        Text(L10n.string("settings.max_clips"))
                    }
                    TextField("", value: $settings.maxClips, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                    Text(L10n.string("settings.max_clips.unit"))
                }
                Text(String(format: L10n.string("settings.max_clips.note"), Limits.countRange.lowerBound, Limits.countRange.upperBound))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
    }
}

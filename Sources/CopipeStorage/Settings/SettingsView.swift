import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Bindable var launchAtLogin: LaunchAtLogin

    var body: some View {
        TabView {
            GeneralSettingsView(settings: settings, launchAtLogin: launchAtLogin)
                .tabItem { Label(L10n.string("settings.general"), systemImage: "gearshape") }
            AboutView()
                .tabItem { Label(L10n.string("settings.about"), systemImage: "info.circle") }
        }
        // グループ化した Form は固有の高さを持たないため、ウィンドウの高さを固定する
        .frame(width: 480, height: 440)
    }
}

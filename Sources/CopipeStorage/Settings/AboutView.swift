import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("app.name"))
                .font(.title2)
            Text(String(format: L10n.string("about.version"), version))
                .foregroundStyle(.secondary)
            Text(Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            Text(L10n.string("about.libraries"))
                .font(.headline)
            ForEach(ThirdPartyLicenses.entries, id: \.name) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Link(entry.name, destination: URL(string: entry.url)!)
                    ScrollView {
                        Text(entry.text)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 140)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                }
            }
        }
        .padding(20)
    }
}

import SwiftUI

struct CreditsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credits")
                .font(.headline)

            creditEntry("Illustrations by Pablo Stanley", url: Credits.buttsssURL, license: "CC BY 4.0")
            creditEntry("Sound by jixolros", url: Credits.freesoundURL)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func creditEntry(_ title: String, url: URL, license: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            HStack(spacing: 4) {
                Text(url.host ?? "")
                    .underline()
                    .onTapGesture { NSWorkspace.shared.open(url) }
                if let license {
                    Text("·")
                    Text(license)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

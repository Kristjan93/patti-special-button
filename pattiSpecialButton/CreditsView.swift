import SwiftUI

struct CreditsView: View {
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("PattiSpecialButton")
                .font(.headline)
            Text("v\(version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image("GitHubMark")
                    .resizable()
                    .frame(width: 14, height: 14)
                Text("Kristjan93")
                    .underline()
            }
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture { NSWorkspace.shared.open(Credits.githubURL) }

            Divider()
                .padding(.horizontal)

            VStack(spacing: 2) {
                link("Illustrations by Pablo Stanley", url: Credits.buttsssURL)
                link("CC BY 4.0", url: Credits.licenseURL)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func link(_ title: String, url: URL) -> some View {
        Text(title)
            .underline()
            .onHover { inside in
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
            .onTapGesture { NSWorkspace.shared.open(url) }
    }
}

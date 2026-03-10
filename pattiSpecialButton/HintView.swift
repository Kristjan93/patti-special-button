import SwiftUI

struct HintView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Right-click for options")
                .font(.system(size: 13, weight: .bold))
            Text("Change icon, sound, and more")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

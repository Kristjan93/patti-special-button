import SwiftUI

struct KeyboardHintsBar: View {
    let hints: [(key: String, label: String)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints, id: \.key) { hint in
                keyHint(hint.key, hint.label)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
                )
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

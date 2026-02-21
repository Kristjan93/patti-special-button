import SwiftUI
import Combine

extension Notification.Name {
    static let previewButt = Notification.Name("previewButt")
    static let moveFocus = Notification.Name("moveFocus")
    static let selectButtFocus = Notification.Name("selectButtFocus")
}

struct ButtPickerView: View {
    @AppStorage(Defaults.selectedButtIdKey) private var selectedButtId = Defaults.defaultButtId
    @AppStorage(Defaults.displayModeKey) private var displayMode = Defaults.defaultDisplayMode
    @State private var focusedIndex: Int = 0

    private let butts: [ButtInfo] = loadButtManifest()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: Layout.gridColumns)

    var body: some View {
        ScrollViewReader { proxy in
            scrollContent(proxy: proxy)
                .onReceive(NotificationCenter.default.publisher(for: .moveFocus)) { notification in
                    guard let offset = notification.userInfo?["offset"] as? Int else { return }
                    move(offset, proxy: proxy)
                }
                .onReceive(NotificationCenter.default.publisher(for: .selectButtFocus)) { _ in
                    guard focusedIndex >= 0, focusedIndex < butts.count else { return }
                    selectedButtId = butts[focusedIndex].id
                }
                .onAppear {
                    if let index = butts.firstIndex(where: { $0.id == selectedButtId }) {
                        focusedIndex = index
                        proxy.scrollTo("\(butts[index].id)-\(displayMode)")
                    }
                }
        }
    }

    private var buttGridContent: some View {
        LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(Array(butts.enumerated()), id: \.element.id) { index, butt in
                AnimatedButtCell(
                    butt: butt,
                    isSelected: butt.id == selectedButtId,
                    isFocused: index == focusedIndex,
                    displayMode: displayMode == DisplayMode.fill.rawValue ? DisplayMode.original.rawValue : displayMode,
                    onTap: {
                        focusedIndex = index
                        selectedButtId = butt.id
                    }
                )
                .id("\(butt.id)-\(displayMode)")
            }
        }
        .padding(Layout.gridPadding)
    }

    @ViewBuilder
    private func scrollContent(proxy: ScrollViewProxy) -> some View {
        if #available(macOS 13.0, *) {
            ScrollView { buttGridContent }
                .safeAreaInset(edge: .bottom) { keyboardHintsBar }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack(alignment: .bottom) {
                ScrollView { buttGridContent.padding(.bottom, 36) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                keyboardHintsBar
            }
        }
    }

    private var keyboardHintsBar: some View {
        HStack(spacing: 14) {
            keyHint("\u{2190}\u{2192}\u{2191}\u{2193}", "Preview")
            keyHint("Space", "Select")
            keyHint("\u{21A9}", "Select + Close")
            keyHint("Esc", "Close")
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

    private func move(_ offset: Int, proxy: ScrollViewProxy) {
        let newIndex = focusedIndex + offset
        guard newIndex >= 0 && newIndex < butts.count else { return }
        focusedIndex = newIndex
        withAnimation { proxy.scrollTo("\(butts[newIndex].id)-\(displayMode)") }
        NotificationCenter.default.post(
            name: .previewButt, object: nil,
            userInfo: ["buttId": butts[newIndex].id]
        )
    }
}

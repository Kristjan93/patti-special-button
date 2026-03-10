import SwiftUI
import Combine

struct ButtPickerView: View {
    @AppStorage(Defaults.selectedButtIdKey) private var selectedButtId = Defaults.defaultButtId
    @AppStorage(Defaults.displayModeKey) private var displayMode = Defaults.defaultDisplayMode
    @AppStorage(Defaults.lineWeightKey) private var lineWeight = Defaults.defaultLineWeight
    @State private var focusedIndex: Int = 0

    private var parsedDisplayMode: DisplayMode {
        DisplayMode(rawValue: displayMode) ?? .stencil
    }

    private var parsedLineWeight: LineWeight {
        LineWeight(rawValue: lineWeight) ?? .regular
    }

    private let butts: [ButtInfo] = buttManifest
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
                        proxy.scrollTo("\(butts[index].id)-\(displayMode)-\(lineWeight)")
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
                    // Stencil mode's inverted-alpha rectangles are unreadable at grid size — show Original instead
                    displayMode: parsedDisplayMode == .stencil ? .original : parsedDisplayMode,
                    lineWeight: parsedLineWeight,
                    onTap: {
                        focusedIndex = index
                        selectedButtId = butt.id
                    }
                )
                .id("\(butt.id)-\(displayMode)-\(lineWeight)")
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
        KeyboardHintsBar(hints: [
            ("\u{2190}\u{2192}\u{2191}\u{2193}", "Preview"),
            ("Space", "Select"),
            ("\u{21A9}", "Select + Close"),
            ("Esc", "Close"),
        ])
    }

    private func move(_ offset: Int, proxy: ScrollViewProxy) {
        let newIndex = focusedIndex + offset
        guard newIndex >= 0 && newIndex < butts.count else { return }
        focusedIndex = newIndex
        withAnimation { proxy.scrollTo("\(butts[newIndex].id)-\(displayMode)-\(lineWeight)") }
        NotificationCenter.default.post(
            name: .previewButt, object: nil,
            userInfo: ["buttId": butts[newIndex].id]
        )
    }
}

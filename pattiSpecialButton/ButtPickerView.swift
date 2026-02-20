import SwiftUI

extension Notification.Name {
    static let previewButt = Notification.Name("previewButt")
    static let confirmAndClose = Notification.Name("confirmAndClose")
}

struct ButtPickerView: View {
    @AppStorage("selectedButtId") private var selectedButtId = "async-butt"
    @State private var focusedIndex: Int = 0

    private let butts: [ButtInfo] = loadButtManifest()
    private static let columnCount = 4
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(butts.enumerated()), id: \.element.id) { index, butt in
                        AnimatedButtCell(
                            butt: butt,
                            isSelected: butt.id == selectedButtId,
                            isFocused: index == focusedIndex,
                            onTap: {
                                focusedIndex = index
                                selectedButtId = butt.id
                            }
                        )
                        .id(index)
                    }
                }
                .padding(16)
            }
            .contentMargins(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .focusable()
            .onKeyPress(.leftArrow) { move(-1, proxy: proxy) }
            .onKeyPress(.rightArrow) { move(1, proxy: proxy) }
            .onKeyPress(.upArrow) { move(-Self.columnCount, proxy: proxy) }
            .onKeyPress(.downArrow) { move(Self.columnCount, proxy: proxy) }
            .onKeyPress(.return) { selectFocused() }
            .onAppear {
                if let index = butts.firstIndex(where: { $0.id == selectedButtId }) {
                    focusedIndex = index
                    proxy.scrollTo(index)
                }
            }
        }
    }

    private func move(_ offset: Int, proxy: ScrollViewProxy) -> KeyPress.Result {
        let newIndex = focusedIndex + offset
        guard newIndex >= 0 && newIndex < butts.count else { return .handled }
        focusedIndex = newIndex
        withAnimation { proxy.scrollTo(newIndex) }
        NotificationCenter.default.post(
            name: .previewButt, object: nil,
            userInfo: ["buttId": butts[newIndex].id]
        )
        return .handled
    }

    private func selectFocused() -> KeyPress.Result {
        selectedButtId = butts[focusedIndex].id
        NotificationCenter.default.post(name: .confirmAndClose, object: nil)
        return .handled
    }
}

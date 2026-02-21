import SwiftUI
import Combine

extension Notification.Name {
    static let previewButt = Notification.Name("previewButt")
    static let moveFocus = Notification.Name("moveFocus")
}

struct ButtPickerView: View {
    @AppStorage(Defaults.selectedButtIdKey) private var selectedButtId = Defaults.defaultButtId
    @AppStorage(Defaults.displayModeKey) private var displayMode = Defaults.defaultDisplayMode
    @State private var focusedIndex: Int = 0

    private let butts: [ButtInfo] = loadButtManifest()
    private let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: Layout.gridColumns)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
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
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(NotificationCenter.default.publisher(for: .moveFocus)) { notification in
                guard let offset = notification.userInfo?["offset"] as? Int else { return }
                move(offset, proxy: proxy)
            }
            .onAppear {
                if let index = butts.firstIndex(where: { $0.id == selectedButtId }) {
                    focusedIndex = index
                    proxy.scrollTo("\(butts[index].id)-\(displayMode)")
                }
            }
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

import SwiftUI

struct ButtPickerView: View {
    @AppStorage("selectedButtId") private var selectedButtId = "async-butt"

    private let butts: [ButtInfo] = loadButtManifest()
    private let columns = [GridItem(.adaptive(minimum: 100))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(butts) { butt in
                    AnimatedButtCell(
                        butt: butt,
                        isSelected: butt.id == selectedButtId,
                        onTap: { selectedButtId = butt.id }
                    )
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

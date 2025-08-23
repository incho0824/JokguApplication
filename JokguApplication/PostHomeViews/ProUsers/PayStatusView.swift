import SwiftUI

struct PayStatusView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var userFields: [String: [Int]] = [:]
    @State private var scrollOffset: CGPoint = .zero

    private let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    private let firstColumnWidth: CGFloat = 80
    private let rowHeight: CGFloat = 40

    private struct ScrollOffsetKey: PreferenceKey {
        static var defaultValue: CGPoint = .zero
        static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
            value = nextValue()
        }
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let columnWidth = max(80, (geometry.size.width - firstColumnWidth) / CGFloat(max(members.count, 1)))

                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow(columnWidth: columnWidth)
                        ForEach(0..<months.count, id: \.self) { index in
                            rowView(for: index, columnWidth: columnWidth)
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named("scroll")).origin)
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }
                .overlay(alignment: .topLeading) {
                    headerRow(columnWidth: columnWidth)
                        .background(Color.white)
                        .offset(x: scrollOffset.x)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
                .overlay(alignment: .topLeading) {
                    monthColumnOverlay()
                        .background(Color.white)
                        .offset(y: scrollOffset.y)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
                .overlay(alignment: .topLeading) {
                    topLeftCellOverlay()
                        .background(Color.white)
                        .allowsHitTesting(false)
                        .zIndex(2)
                }
            }
            .navigationTitle("Membership")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear { loadData() }
        }
    }

    private func headerRow(columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: firstColumnWidth, height: rowHeight)
                .border(Color.gray)
            ForEach(members) { member in
                Text(member.username)
                    .frame(width: columnWidth, height: rowHeight)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
    }

    private func rowView(for monthIndex: Int, columnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(months[monthIndex])
                .frame(width: firstColumnWidth, height: rowHeight, alignment: .leading)
                .border(Color.gray)
            ForEach(members) { member in
                let fields = userFields[member.username] ?? []
                let value = monthIndex < fields.count ? fields[monthIndex] : 0
                Text(value > 0 ? "\(value)" : "-")
                    .frame(width: columnWidth, height: rowHeight)
                    .background(value > 0 ? Color.green.opacity(0.3) : Color.clear)
                    .border(Color.gray)
            }
        }
    }

    private func monthColumnOverlay() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("")
                .frame(width: firstColumnWidth, height: rowHeight)
            ForEach(0..<months.count, id: \.self) { index in
                Text(months[index])
                    .frame(width: firstColumnWidth, height: rowHeight, alignment: .leading)
                    .border(Color.gray)
            }
        }
    }

    private func topLeftCellOverlay() -> some View {
        Text("")
            .frame(width: firstColumnWidth, height: rowHeight)
            .border(Color.gray)
    }

    private func loadData() {
        members = DatabaseManager.shared.fetchMembers()
        var dict: [String: [Int]] = [:]
        for member in members {
            if let values = DatabaseManager.shared.fetchUserFields(username: member.username) {
                dict[member.username] = values
            } else {
                dict[member.username] = []
            }
        }
        userFields = dict
    }
}

#Preview {
    PayStatusView()
}

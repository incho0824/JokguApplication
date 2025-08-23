import SwiftUI

struct PayStatusView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var userFields: [String: [Int]] = [:]
    private let months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    @State private var scrollOffset: CGPoint = .zero
    private let cellWidth: CGFloat = 80
    private let cellHeight: CGFloat = 40

    var body: some View {
        NavigationView {
            ZStack(alignment: .topLeading) {
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow()
                        ForEach(0..<months.count, id: \.self) { index in
                            rowView(for: index)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).origin)
                    })
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    scrollOffset = CGPoint(x: -value.x, y: -value.y)
                }

                columnOverlay()
                headerOverlay()
                topLeftCell()
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

    private func headerRow() -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: cellWidth, height: cellHeight)
                .border(Color.gray)
            ForEach(members) { member in
                verticalName(member)
                    .frame(width: cellWidth, height: cellHeight)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
    }

    private func rowView(for monthIndex: Int) -> some View {
        HStack(spacing: 0) {
            Text(months[monthIndex])
                .frame(width: cellWidth, height: cellHeight, alignment: .leading)
                .border(Color.gray)
            ForEach(members) { member in
                let fields = userFields[member.username] ?? []
                let value = monthIndex < fields.count ? fields[monthIndex] : 0
                Text(value > 0 ? "\(value)" : "-")
                    .frame(width: cellWidth, height: cellHeight)
                    .background(value > 0 ? Color.green.opacity(0.3) : Color.clear)
                    .border(Color.gray)
            }
        }
    }

    private func verticalName(_ member: Member) -> some View {
        let name = member.lastName + member.firstName
        return VStack(spacing: 0) {
            ForEach(Array(name), id: \.self) { char in
                Text(String(char))
            }
        }
    }

    private func columnOverlay() -> some View {
        VStack(spacing: 0) {
            ForEach(0..<months.count, id: \.self) { index in
                Text(months[index])
                    .frame(width: cellWidth, height: cellHeight, alignment: .leading)
                    .background(Color.white)
                    .border(Color.gray)
            }
        }
        .padding(.top, cellHeight)
        .offset(y: -scrollOffset.y)
    }

    private func headerOverlay() -> some View {
        HStack(spacing: 0) {
            ForEach(members) { member in
                verticalName(member)
                    .frame(width: cellWidth, height: cellHeight)
                    .background(Color.gray.opacity(0.2))
                    .border(Color.gray)
            }
        }
        .padding(.leading, cellWidth)
        .offset(x: -scrollOffset.x)
    }

    private func topLeftCell() -> some View {
        Text("")
            .frame(width: cellWidth, height: cellHeight)
            .background(Color.white)
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

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

#Preview {
    PayStatusView()
}

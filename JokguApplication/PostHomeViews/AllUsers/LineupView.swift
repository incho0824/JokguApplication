import SwiftUI

struct LineupView: View {
    @Environment(\.dismiss) var dismiss
    var username: String
    @State private var members: [Member] = []
    @State private var showTodayPrompt = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(members) { member in
                            VStack {
                                if let data = member.picture,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image("default-profile")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                }
                                Text("\(member.lastName) \(member.firstName)")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                }
                Button("Count me in!") {
                    showTodayPrompt = true
                }
                .padding()
            }
            .navigationTitle("Today's Lineup")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                members = DatabaseManager.shared.fetchTodayMembers()
            }
            .todayPrompt(isPresented: $showTodayPrompt, username: username) {
                members = DatabaseManager.shared.fetchTodayMembers()
            }
        }
    }
}

#Preview {
    LineupView(username: "USER")
}

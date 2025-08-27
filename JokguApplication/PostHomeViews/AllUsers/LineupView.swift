import SwiftUI

struct LineupView: View {
    @Environment(\.dismiss) var dismiss
    var username: String
    @State private var members: [Member] = []
    @State private var showTodayPrompt = false
    @State private var isPlayDay = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var userInLineup: Bool {
        members.contains { $0.username.uppercased() == username.uppercased() }
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(members) { member in
                            VStack {
                                if let urlString = member.pictureURL,
                                   let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Image("default-profile")
                                                .resizable()
                                                .scaledToFill()
                                        }
                                    }
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
                if isPlayDay {
                    if userInLineup {
                        Button("Count me out...") {
                            showTodayPrompt = true
                        }
                        .foregroundColor(.red)
                        .padding()
                    } else {
                        Button("Count me in!") {
                            showTodayPrompt = true
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Today's Lineup")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .onAppear {
                Task {
                    if let fetched = try? await DatabaseManager.shared.fetchTodayMembers() {
                        await MainActor.run { members = fetched }
                    }
                    checkPlayDay()
                }
            }
            .todayPrompt(isPresented: $showTodayPrompt, username: username) {
                Task {
                    if let fetched = try? await DatabaseManager.shared.fetchTodayMembers() {
                        await MainActor.run { members = fetched }
                    }
                }
            }
        }
    }
}

private extension LineupView {
    func checkPlayDay() {
        Task {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let today = formatter.string(from: Date())
            do {
                let managements = try await DatabaseManager.shared.fetchManagementData()
                await MainActor.run {
                    isPlayDay = managements.first?.playwhen.contains(today) ?? false
                }
            } catch {
                await MainActor.run { isPlayDay = false }
            }
        }
    }
}

#Preview {
    LineupView(username: "USER")
}

import SwiftUI

extension View {
    func todayPrompt(isPresented: Binding<Bool>, username: String, onDecision: (() -> Void)? = nil) -> some View {
        self.alert("Jokgu Today—YOU IN?", isPresented: isPresented) {
            Button("Yes") {
                Task {
                    try? await DatabaseManager.shared.updateToday(username: username, value: 1)
                    await MainActor.run {
                        isPresented.wrappedValue = false
                        onDecision?()
                    }
                }
            }
            Button("No") {
                Task {
                    try? await DatabaseManager.shared.updateToday(username: username, value: 2)
                    await MainActor.run {
                        isPresented.wrappedValue = false
                        onDecision?()
                    }
                }
            }
        }
    }
}


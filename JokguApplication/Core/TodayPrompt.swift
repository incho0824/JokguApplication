import SwiftUI

extension View {
    func todayPrompt(isPresented: Binding<Bool>, username: String, onDecision: (() -> Void)? = nil) -> some View {
        self.alert("Jokgu Today—YOU IN?", isPresented: isPresented) {
            Button("Yes") {
                _ = DatabaseManager.shared.updateToday(username: username, value: 1)
                isPresented.wrappedValue = false
                onDecision?()
            }
            Button("No") {
                _ = DatabaseManager.shared.updateToday(username: username, value: 2)
                isPresented.wrappedValue = false
                onDecision?()
            }
        }
    }
}


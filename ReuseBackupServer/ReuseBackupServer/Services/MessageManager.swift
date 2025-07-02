import Foundation

final class MessageManager: ObservableObject, @unchecked Sendable {
    @Published private(set) var messages: [String] = []

    func addMessage(_ message: String) {
        messages.append(message)
    }

    func getMessages() -> [String] {
        return messages
    }

    func clearMessages() {
        messages.removeAll()
    }
}

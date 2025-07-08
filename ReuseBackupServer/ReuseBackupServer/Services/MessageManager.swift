import Foundation

@MainActor
final class MessageManager: ObservableObject {
    @Published private(set) var messages: [String] = []

    func addMessage(_ message: String) {
        messages.append(message)
        print("メッセージ追加: \(message). 総メッセージ数: \(messages.count)")
    }

    func getMessages() -> [String] {
        messages
    }

    func clearMessages() {
        messages.removeAll()
        print("メッセージクリア完了")
    }
}

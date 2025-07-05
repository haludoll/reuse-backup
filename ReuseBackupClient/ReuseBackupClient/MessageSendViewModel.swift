import Foundation
import APISharedModels

@MainActor
class MessageSendViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isSending = false
    @Published var lastResponse: Components.Schemas.MessageResponse?
    @Published var errorMessage: String?
    @Published var serverURL: URL?
    
    private let httpClient = HTTPClient()
    
    func discoverServer() async {
        errorMessage = nil
        
        // まずローカルホストでテスト
        let testURL = URL(string: "http://localhost:8080")!
        
        do {
            let statusResponse = try await httpClient.checkServerStatus(baseURL: testURL)
            serverURL = testURL
            isConnected = true
            print("サーバーが見つかりました: \(testURL)")
        } catch {
            isConnected = false
            serverURL = nil
            errorMessage = "サーバーが見つかりません: \(error.localizedDescription)"
            print("サーバー検出エラー: \(error)")
        }
    }
    
    func sendMessage(_ message: String) async {
        guard let serverURL = serverURL else {
            errorMessage = "サーバーが設定されていません"
            return
        }
        
        isSending = true
        errorMessage = nil
        
        do {
            let messageRequest = Components.Schemas.MessageRequest(
                message: message,
                timestamp: Date()
            )
            
            let response = try await httpClient.sendMessage(
                baseURL: serverURL,
                messageRequest: messageRequest
            )
            
            lastResponse = response
            print("メッセージ送信成功: \(response)")
        } catch {
            errorMessage = "メッセージ送信エラー: \(error.localizedDescription)"
            print("メッセージ送信エラー: \(error)")
        }
        
        isSending = false
    }
}
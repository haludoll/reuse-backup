import Foundation
import APISharedModels

@MainActor
class MessageSendViewModel: ObservableObject {
    @Published var isConnected = false
    @Published var isSending = false
    @Published var lastResponse: Components.Schemas.MessageResponse?
    @Published var errorMessage: String?
    @Published var serverURL: URL?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var showingSuccessAlert = false
    @Published var showingErrorAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    private let httpClient = HTTPClient()
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error
    }
    
    func discoverServer() async {
        connectionStatus = .connecting
        errorMessage = nil
        
        // まずローカルホストでテスト
        let testURL = URL(string: "http://localhost:8080")!
        
        do {
            let statusResponse = try await httpClient.checkServerStatus(baseURL: testURL)
            serverURL = testURL
            isConnected = true
            connectionStatus = .connected
            print("サーバーが見つかりました: \(testURL)")
        } catch {
            isConnected = false
            serverURL = nil
            connectionStatus = .error
            errorMessage = getDetailedErrorMessage(error)
            print("サーバー検出エラー: \(error)")
        }
    }
    
    func sendMessage(_ message: String) async {
        guard let serverURL = serverURL else {
            showError("接続エラー", "サーバーが設定されていません。先にサーバー検索を実行してください。")
            return
        }
        
        // メッセージの検証
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("入力エラー", "メッセージが空です。")
            return
        }
        
        guard message.count <= 1000 else {
            showError("入力エラー", "メッセージは1000文字以内で入力してください。")
            return
        }
        
        isSending = true
        errorMessage = nil
        
        do {
            let messageRequest = Components.Schemas.MessageRequest(
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                timestamp: Date()
            )
            
            let response = try await httpClient.sendMessage(
                baseURL: serverURL,
                messageRequest: messageRequest
            )
            
            lastResponse = response
            showSuccess("送信完了", "メッセージが正常に送信されました。")
            print("メッセージ送信成功: \(response)")
        } catch {
            let detailedError = getDetailedErrorMessage(error)
            errorMessage = detailedError
            showError("送信エラー", detailedError)
            print("メッセージ送信エラー: \(error)")
        }
        
        isSending = false
    }
    
    private func showSuccess(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingSuccessAlert = true
    }
    
    private func showError(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showingErrorAlert = true
    }
    
    private func getDetailedErrorMessage(_ error: Error) -> String {
        if let httpError = error as? HTTPClientError {
            switch httpError {
            case .invalidResponse:
                return "サーバーから無効な応答が返されました。"
            case .httpError(let statusCode):
                return getHTTPErrorMessage(statusCode)
            case .encodingError:
                return "リクエストの作成に失敗しました。"
            case .decodingError:
                return "サーバーの応答を解析できませんでした。"
            case .serverError(let errorResponse):
                return "サーバーエラー: \(errorResponse.error ?? "不明なエラー")"
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "インターネット接続を確認してください。"
            case .timedOut:
                return "接続がタイムアウトしました。サーバーが応答していない可能性があります。"
            case .cannotFindHost, .cannotConnectToHost:
                return "サーバーに接続できません。サーバーが起動していることを確認してください。"
            case .networkConnectionLost:
                return "ネットワーク接続が失われました。"
            default:
                return "ネットワークエラー: \(urlError.localizedDescription)"
            }
        } else {
            return "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    private func getHTTPErrorMessage(_ statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "リクエストの形式が正しくありません。"
        case 401:
            return "認証が必要です。"
        case 403:
            return "アクセスが拒否されました。"
        case 404:
            return "サーバーが見つかりません。URLを確認してください。"
        case 405:
            return "許可されていない操作です。"
        case 408:
            return "リクエストがタイムアウトしました。"
        case 429:
            return "リクエストが多すぎます。しばらく待ってから再試行してください。"
        case 500:
            return "サーバー内部エラーが発生しました。"
        case 502:
            return "ゲートウェイエラーです。"
        case 503:
            return "サーバーが一時的に利用できません。"
        case 504:
            return "ゲートウェイタイムアウトです。"
        default:
            return "HTTPエラー: \(statusCode)"
        }
    }
}
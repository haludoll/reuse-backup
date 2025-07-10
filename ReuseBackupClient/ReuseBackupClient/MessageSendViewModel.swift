import APISharedModels
import Foundation

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
    private let serverDiscoveryManager = ServerDiscoveryManager()

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error
    }

    func discoverServer() async {
        connectionStatus = .connecting
        errorMessage = nil

        // Bonjourサービス検索を開始
        serverDiscoveryManager.startDiscovery()

        // 検索完了まで待機
        try? await Task.sleep(nanoseconds: 16_000_000_000) // 16秒待機

        // 発見されたサーバーを確認
        let discoveredServers = serverDiscoveryManager.discoveredServers

        if discoveredServers.isEmpty {
            isConnected = false
            serverURL = nil
            connectionStatus = .error
            errorMessage = "利用可能なサーバーが見つかりませんでした。サーバーが起動していることを確認してください。"
            return
        }

        // 最初に見つかった利用可能なサーバーを使用
        for server in discoveredServers {
            guard let url = URL(string: server.endpoint) else { continue }

            do {
                // サーバーの状態をチェック
                let statusResponse = try await httpClient.checkServerStatus(baseURL: url)
                serverURL = url
                isConnected = true
                connectionStatus = .connected
                print("サーバーが見つかりました: \(url)")
                return
            } catch {
                print("サーバー \(server.endpoint) への接続失敗: \(error)")
                continue
            }
        }

        // すべてのサーバーで接続に失敗
        isConnected = false
        serverURL = nil
        connectionStatus = .error
        errorMessage = "発見されたサーバーに接続できませんでした。"
    }

    func sendMessage(_ message: String) async {
        guard let serverURL else {
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
                "サーバーから無効な応答が返されました。"
            case let .httpError(statusCode):
                getHTTPErrorMessage(statusCode)
            case .encodingError:
                "リクエストの作成に失敗しました。"
            case .decodingError:
                "サーバーの応答を解析できませんでした。"
            case let .serverError(errorResponse):
                "サーバーエラー: \(errorResponse.error ?? "不明なエラー")"
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                "インターネット接続を確認してください。"
            case .timedOut:
                "接続がタイムアウトしました。サーバーが応答していない可能性があります。"
            case .cannotFindHost, .cannotConnectToHost:
                "サーバーに接続できません。サーバーが起動していることを確認してください。"
            case .networkConnectionLost:
                "ネットワーク接続が失われました。"
            default:
                "ネットワークエラー: \(urlError.localizedDescription)"
            }
        } else {
            "予期しないエラーが発生しました: \(error.localizedDescription)"
        }
    }

    private func getHTTPErrorMessage(_ statusCode: Int) -> String {
        switch statusCode {
        case 400:
            "リクエストの形式が正しくありません。"
        case 401:
            "認証が必要です。"
        case 403:
            "アクセスが拒否されました。"
        case 404:
            "サーバーが見つかりません。URLを確認してください。"
        case 405:
            "許可されていない操作です。"
        case 408:
            "リクエストがタイムアウトしました。"
        case 429:
            "リクエストが多すぎます。しばらく待ってから再試行してください。"
        case 500:
            "サーバー内部エラーが発生しました。"
        case 502:
            "ゲートウェイエラーです。"
        case 503:
            "サーバーが一時的に利用できません。"
        case 504:
            "ゲートウェイタイムアウトです。"
        default:
            "HTTPエラー: \(statusCode)"
        }
    }
}

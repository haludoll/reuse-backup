import Foundation
import APISharedModels

class HTTPClient: NSObject {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    /// HTTPS通信に対応しているかどうか
    var supportsHTTPS: Bool { return true }
    
    /// 自己署名証明書を許可するかどうか
    var allowsSelfSignedCertificates: Bool { return true }
    
    override init() {
        // mDNS接続用に最適化したURLSession設定
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0  // mDNS解決のため長めに設定
        config.timeoutIntervalForResource = 30.0
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        super.init()
        
        // HTTPS自己署名証明書対応のためのデリゲート設定
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    func checkServerStatus(baseURL: URL) async throws -> Components.Schemas.ServerStatus {
        let url = baseURL.appendingPathComponent("/api/status")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0  // mDNS解決を考慮して延長
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw HTTPClientError.httpError(statusCode: httpResponse.statusCode)
        }
        
        do {
            let statusResponse = try decoder.decode(Components.Schemas.ServerStatus.self, from: data)
            return statusResponse
        } catch {
            throw HTTPClientError.decodingError(error)
        }
    }
    
    func sendMessage(baseURL: URL, messageRequest: Components.Schemas.MessageRequest) async throws -> Components.Schemas.MessageResponse {
        let url = baseURL.appendingPathComponent("/api/message")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0  // mDNS解決を考慮して延長
        
        do {
            let requestData = try encoder.encode(messageRequest)
            request.httpBody = requestData
        } catch {
            throw HTTPClientError.encodingError(error)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            do {
                let messageResponse = try decoder.decode(Components.Schemas.MessageResponse.self, from: data)
                return messageResponse
            } catch {
                throw HTTPClientError.decodingError(error)
            }
        } else {
            do {
                let errorResponse = try decoder.decode(Components.Schemas.ErrorResponse.self, from: data)
                throw HTTPClientError.serverError(errorResponse)
            } catch {
                throw HTTPClientError.httpError(statusCode: httpResponse.statusCode)
            }
        }
    }
}

enum HTTPClientError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case encodingError(Error)
    case decodingError(Error)
    case serverError(Components.Schemas.ErrorResponse)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無効なレスポンス"
        case .httpError(let statusCode):
            return "HTTPエラー: \(statusCode)"
        case .encodingError(let error):
            return "エンコードエラー: \(error.localizedDescription)"
        case .decodingError(let error):
            return "デコードエラー: \(error.localizedDescription)"
        case .serverError(let errorResponse):
            return "サーバーエラー: \(errorResponse.error ?? "不明なエラー")"
        }
    }
}

// MARK: - URLSessionDelegate

extension HTTPClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // サーバー認証の場合のみ処理
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 自己署名証明書を許可する場合
        if allowsSelfSignedCertificates {
            // ローカルホストまたはプライベートネットワークのIPアドレスの場合のみ許可
            let host = challenge.protectionSpace.host
            if isLocalNetworkHost(host) {
                // サーバー信頼性を取得
                guard let serverTrust = challenge.protectionSpace.serverTrust else {
                    completionHandler(.performDefaultHandling, nil)
                    return
                }
                
                // 認証情報を作成して許可
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        
        // それ以外の場合はデフォルトの処理
        completionHandler(.performDefaultHandling, nil)
    }
    
    /// ローカルネットワークのホストかどうかを判定
    private func isLocalNetworkHost(_ host: String) -> Bool {
        // localhost
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return true
        }
        
        // プライベートIPアドレス範囲
        let privateRanges = [
            "192.168.",  // 192.168.0.0/16
            "10.",       // 10.0.0.0/8
            "172.16.",   // 172.16.0.0/12 - 172.31.255.255/12
            "172.17.",
            "172.18.",
            "172.19.",
            "172.20.",
            "172.21.",
            "172.22.",
            "172.23.",
            "172.24.",
            "172.25.",
            "172.26.",
            "172.27.",
            "172.28.",
            "172.29.",
            "172.30.",
            "172.31."
        ]
        
        return privateRanges.contains { host.hasPrefix($0) }
    }
}
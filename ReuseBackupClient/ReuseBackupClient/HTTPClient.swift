import APISharedModels
import AVFoundation
import Foundation

class HTTPClient: NSObject {
    private var session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// HTTPS通信に対応しているかどうか
    var supportsHTTPS: Bool { true }

    /// 自己署名証明書を許可するかどうか
    var allowsSelfSignedCertificates: Bool { true }

    override init() {
        // mDNS接続用に最適化したURLSession設定
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0 // mDNS解決のため長めに設定
        config.timeoutIntervalForResource = 30.0

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        // 初期化時は一時的なセッションを作成
        session = URLSession(configuration: config)

        super.init()

        // HTTPS自己署名証明書対応のためのデリゲート設定
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func checkServerStatus(baseURL: URL) async throws -> Components.Schemas.ServerStatus {
        let url = baseURL.appendingPathComponent("/api/status")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // mDNS解決を考慮して延長

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

    func sendMessage(baseURL: URL, messageRequest: Components.Schemas.MessageRequest) async throws -> Components.Schemas
        .MessageResponse
    {
        let url = baseURL.appendingPathComponent("/api/message")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0 // mDNS解決を考慮して延長

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

    /// メディアファイルをアップロード
    func uploadMedia(
        baseURL: URL,
        mediaData: MediaUploadData,
        progressHandler: @escaping (Double) -> Void = { _ in }
    ) async throws -> Components.Schemas.MediaUploadResponse {
        let url = baseURL.appendingPathComponent("/api/media/upload")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300.0 // 大きなファイル対応のため延長

        // マルチパートデータを作成
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let multipartData = createMultipartData(
            mediaData: mediaData,
            boundary: boundary
        )

        // プログレス対応のアップロード
        let (data, response) = try await uploadWithProgress(request: request, data: multipartData, progressHandler: progressHandler)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            do {
                let uploadResponse = try decoder.decode(Components.Schemas.MediaUploadResponse.self, from: data)
                return uploadResponse
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

    /// マルチパートデータを作成
    private func createMultipartData(mediaData: MediaUploadData, boundary: String) -> Data {
        var data = Data()
        let lineBreak = "\r\n"

        // ファイルデータ
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data
            .append("Content-Disposition: form-data; name=\"file\"; filename=\"\(mediaData.filename)\"\(lineBreak)"
                .data(using: .utf8)!
            )
        data.append("Content-Type: \(mediaData.mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(mediaData.data)
        data.append(lineBreak.data(using: .utf8)!)

        // ファイル名
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"filename\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(mediaData.filename.data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)

        // ファイルサイズ
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"fileSize\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append("\(mediaData.fileSize)".data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)

        // MIMEタイプ
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"mimeType\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(mediaData.mimeType.data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)

        // メディアタイプ
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"mediaType\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(mediaData.mediaType.rawValue.data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)

        // タイムスタンプ
        let iso8601Formatter = ISO8601DateFormatter()
        let timestampString = iso8601Formatter.string(from: mediaData.timestamp)
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"timestamp\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(timestampString.data(using: .utf8)!)
        data.append(lineBreak.data(using: .utf8)!)

        // 終了境界
        data.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)

        return data
    }

    /// プログレス対応のアップロード
    private func uploadWithProgress(
        request: URLRequest,
        data: Data,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: data) { responseData, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let responseData, let response {
                    continuation.resume(returning: (responseData, response))
                } else {
                    continuation.resume(throwing: HTTPClientError.invalidResponse)
                }
            }

            // プログレス監視
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                Task { @MainActor in
                    progressHandler(progress.fractionCompleted)
                }
            }

            task.resume()

            // タスク完了時に監視を停止
            Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
                while task.state == .running {
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
                observation.invalidate()
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
            "無効なレスポンス"
        case let .httpError(statusCode):
            "HTTPエラー: \(statusCode)"
        case let .encodingError(error):
            "エンコードエラー: \(error.localizedDescription)"
        case let .decodingError(error):
            "デコードエラー: \(error.localizedDescription)"
        case let .serverError(errorResponse):
            "サーバーエラー: \(errorResponse.error)"
        }
    }
}

// MARK: - URLSessionDelegate

extension HTTPClient: URLSessionDelegate {
    func urlSession(
        _: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
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
            "192.168.", // 192.168.0.0/16
            "10.", // 10.0.0.0/8
            "172.16.", // 172.16.0.0/12 - 172.31.255.255/12
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
            "172.31.",
        ]

        return privateRanges.contains { host.hasPrefix($0) }
    }
}

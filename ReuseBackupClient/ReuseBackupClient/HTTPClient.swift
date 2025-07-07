import Foundation
import APISharedModels

class HTTPClient {
    private let session = URLSession.shared
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }
    
    func checkServerStatus(baseURL: URL) async throws -> Components.Schemas.ServerStatus {
        let url = baseURL.appendingPathComponent("/api/status")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5.0
        
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
        request.timeoutInterval = 10.0
        
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